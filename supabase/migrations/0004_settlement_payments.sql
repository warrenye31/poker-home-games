-- PokerNight — sync "paid" checkmarks to viewers
-- ==========================================================================
-- Paste into the Supabase SQL Editor and Run, after 0003. Run it BEFORE
-- shipping the build that syncs payments: that build reads this table on
-- every viewer pull, so against a database without it every pull fails.
--
-- Until now settlement rows lived only on the organizer's device, so a
-- viewer's Inbox recomputed every transfer, found no paid record for any of
-- them, and listed every debt it had ever seen as still outstanding.
--
-- Same shape and rules as session_entries: group_id is denormalised so RLS
-- needs no join; members read, the organizer alone writes. Deleting a
-- session or a player cascades, matching the local SwiftData relationships.

create table if not exists public.settlement_payments (
  id             uuid primary key,
  group_id       uuid not null references public.groups (id) on delete cascade,
  session_id     uuid not null references public.sessions (id) on delete cascade,
  from_player_id uuid not null references public.players (id) on delete cascade,
  to_player_id   uuid not null references public.players (id) on delete cascade,
  amount         numeric not null default 0,
  is_paid        boolean not null default false,
  updated_at     timestamptz not null default now()
);
create index if not exists settlement_payments_group_id_idx on public.settlement_payments (group_id);
create index if not exists settlement_payments_session_id_idx on public.settlement_payments (session_id);

drop trigger if exists settlement_payments_touch on public.settlement_payments;
create trigger settlement_payments_touch before update on public.settlement_payments
  for each row execute function public.touch_updated_at();

alter table public.settlement_payments enable row level security;

drop policy if exists settlement_payments_select on public.settlement_payments;
create policy settlement_payments_select on public.settlement_payments
  for select to authenticated
  using (public.is_group_member(group_id));

drop policy if exists settlement_payments_write on public.settlement_payments;
create policy settlement_payments_write on public.settlement_payments
  for all to authenticated
  using (public.is_group_admin(group_id))
  with check (public.is_group_admin(group_id));

do $$
begin
  alter publication supabase_realtime add table public.settlement_payments;
exception when duplicate_object then null;
end $$;
