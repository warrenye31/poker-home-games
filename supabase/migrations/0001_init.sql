-- PokerNight — Phase 1 schema + Row Level Security
-- =================================================
-- Paste this whole file into the Supabase SQL Editor (SQL → New query) and Run.
-- It is idempotent enough to re-run during development, but review before
-- running against data you care about.
--
-- Model:
--   * Every device signs in with ANONYMOUS auth, so each device has a stable
--     auth.uid(). No sign-up.
--   * A `group` is owned by the device that created it (admin_id = its uid).
--   * Sharing is by a short `join_code`. A viewer calls join_group_with_code()
--     with the code, which records a row in `group_members`.
--   * SELECT (read): the admin, or anyone who has joined via the code.
--   * INSERT/UPDATE/DELETE (write): the admin only.
--
-- Tables mirror the local SwiftData models and are keyed on the app's stable
-- UUIDs (GameGroup.id, Player.id, Session.id, SessionEntry.id). Per-entry
-- money is denormalised onto session_entries (total_buy_in, cash_out) which is
-- all a read-only viewer needs for the leaderboard; individual buy-ins and
-- settlement rows are intentionally NOT mirrored in Phase 1.

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------
create extension if not exists pgcrypto;  -- gen_random_uuid(), gen_random_bytes()

-- ---------------------------------------------------------------------------
-- Helper: short, human-shareable join code (8 chars, unambiguous alphabet)
-- ---------------------------------------------------------------------------
create or replace function public.generate_join_code()
returns text
language plpgsql
volatile
as $$
declare
  -- No 0/O/1/I to avoid confusion when read aloud or typed.
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text := '';
  i int;
begin
  for i in 1..8 loop
    code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
  end loop;
  return code;
end;
$$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
create table if not exists public.groups (
  id           uuid primary key default gen_random_uuid(),
  name         text not null default '',
  created_date timestamptz not null default now(),
  admin_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  join_code    text not null unique default public.generate_join_code(),
  updated_at   timestamptz not null default now()
);

create table if not exists public.players (
  id         uuid primary key,
  group_id   uuid not null references public.groups (id) on delete cascade,
  name       text not null default '',
  updated_at timestamptz not null default now()
);
create index if not exists players_group_id_idx on public.players (group_id);

create table if not exists public.sessions (
  id             uuid primary key,
  group_id       uuid not null references public.groups (id) on delete cascade,
  date           timestamptz not null default now(),
  location       text,
  uses_bank      boolean not null default false,
  bank_player_id uuid references public.players (id) on delete set null,
  small_blind    numeric,
  big_blind      numeric,
  standard_buy_in numeric not null default 20,
  status         text not null default 'active',  -- 'active' | 'completed'
  updated_at     timestamptz not null default now()
);
create index if not exists sessions_group_id_idx on public.sessions (group_id);

create table if not exists public.session_entries (
  id           uuid primary key,
  -- group_id is denormalised from the session so RLS policies don't need a join.
  group_id     uuid not null references public.groups (id) on delete cascade,
  session_id   uuid not null references public.sessions (id) on delete cascade,
  player_id    uuid not null references public.players (id) on delete cascade,
  total_buy_in numeric not null default 0,
  cash_out     numeric,
  updated_at   timestamptz not null default now()
);
create index if not exists session_entries_group_id_idx on public.session_entries (group_id);
create index if not exists session_entries_session_id_idx on public.session_entries (session_id);

-- Membership: who has joined a group via its code (in addition to the admin).
create table if not exists public.group_members (
  group_id  uuid not null references public.groups (id) on delete cascade,
  user_id   uuid not null default auth.uid() references auth.users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

-- ---------------------------------------------------------------------------
-- updated_at maintenance
-- ---------------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists groups_touch on public.groups;
create trigger groups_touch before update on public.groups
  for each row execute function public.touch_updated_at();

drop trigger if exists players_touch on public.players;
create trigger players_touch before update on public.players
  for each row execute function public.touch_updated_at();

drop trigger if exists sessions_touch on public.sessions;
create trigger sessions_touch before update on public.sessions
  for each row execute function public.touch_updated_at();

drop trigger if exists session_entries_touch on public.session_entries;
create trigger session_entries_touch before update on public.session_entries
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Membership helpers (SECURITY DEFINER so they can read past RLS without
-- causing recursive policy evaluation).
-- ---------------------------------------------------------------------------
create or replace function public.is_group_admin(gid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.groups g
    where g.id = gid and g.admin_id = auth.uid()
  );
$$;

create or replace function public.is_group_member(gid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    exists (select 1 from public.groups g where g.id = gid and g.admin_id = auth.uid())
    or exists (select 1 from public.group_members m where m.group_id = gid and m.user_id = auth.uid());
$$;

-- ---------------------------------------------------------------------------
-- Join RPC: validate a code and record membership for the caller.
-- SECURITY DEFINER so the lookup works before the caller can read the group.
-- Returns the joined group row (client uses it to start syncing/subscribing).
-- ---------------------------------------------------------------------------
create or replace function public.join_group_with_code(p_code text)
returns public.groups
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  g public.groups;
begin
  select * into g
  from public.groups
  where join_code = upper(trim(p_code));

  if g.id is null then
    raise exception 'No group found for that code' using errcode = 'no_data_found';
  end if;

  insert into public.group_members (group_id, user_id)
  values (g.id, auth.uid())
  on conflict (group_id, user_id) do nothing;

  return g;
end;
$$;

grant execute on function public.join_group_with_code(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.groups          enable row level security;
alter table public.players         enable row level security;
alter table public.sessions        enable row level security;
alter table public.session_entries enable row level security;
alter table public.group_members   enable row level security;

-- groups ---------------------------------------------------------------------
drop policy if exists groups_select on public.groups;
create policy groups_select on public.groups
  for select to authenticated
  using (public.is_group_member(id));

drop policy if exists groups_insert on public.groups;
create policy groups_insert on public.groups
  for insert to authenticated
  with check (admin_id = auth.uid());

drop policy if exists groups_update on public.groups;
create policy groups_update on public.groups
  for update to authenticated
  using (admin_id = auth.uid())
  with check (admin_id = auth.uid());

drop policy if exists groups_delete on public.groups;
create policy groups_delete on public.groups
  for delete to authenticated
  using (admin_id = auth.uid());

-- players --------------------------------------------------------------------
drop policy if exists players_select on public.players;
create policy players_select on public.players
  for select to authenticated
  using (public.is_group_member(group_id));

drop policy if exists players_write on public.players;
create policy players_write on public.players
  for all to authenticated
  using (public.is_group_admin(group_id))
  with check (public.is_group_admin(group_id));

-- sessions -------------------------------------------------------------------
drop policy if exists sessions_select on public.sessions;
create policy sessions_select on public.sessions
  for select to authenticated
  using (public.is_group_member(group_id));

drop policy if exists sessions_write on public.sessions;
create policy sessions_write on public.sessions
  for all to authenticated
  using (public.is_group_admin(group_id))
  with check (public.is_group_admin(group_id));

-- session_entries ------------------------------------------------------------
drop policy if exists session_entries_select on public.session_entries;
create policy session_entries_select on public.session_entries
  for select to authenticated
  using (public.is_group_member(group_id));

drop policy if exists session_entries_write on public.session_entries;
create policy session_entries_write on public.session_entries
  for all to authenticated
  using (public.is_group_admin(group_id))
  with check (public.is_group_admin(group_id));

-- group_members --------------------------------------------------------------
-- Members are created only through join_group_with_code() (SECURITY DEFINER),
-- so there is deliberately no INSERT policy for direct client inserts.
drop policy if exists group_members_select on public.group_members;
create policy group_members_select on public.group_members
  for select to authenticated
  using (user_id = auth.uid() or public.is_group_admin(group_id));

drop policy if exists group_members_delete on public.group_members;
create policy group_members_delete on public.group_members
  for delete to authenticated
  using (user_id = auth.uid());  -- a viewer can leave a group

-- ---------------------------------------------------------------------------
-- Realtime: let viewer devices subscribe to changes for their group.
-- (RLS still applies to realtime, so viewers only receive rows they can read.)
-- ---------------------------------------------------------------------------
do $$
begin
  alter publication supabase_realtime add table public.groups;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.players;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.sessions;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.session_entries;
exception when duplicate_object then null;
end $$;
