-- PokerNight — fix: admin can't read back a group they just created
-- ==========================================================================
-- Paste into the Supabase SQL Editor and Run, after 0002_admin_player_claim.sql.
--
-- Symptom: sharing a group always failed with
--   42501: new row violates row-level security policy for table "groups"
-- even though groups_insert's `with check (admin_id = auth.uid())` evaluates
-- to true for the row being inserted.
--
-- Cause: the *SELECT* policy, not the INSERT policy. `groups_select` called
-- `is_group_member(id)`, which looks the group up **by id in public.groups** —
-- the same table being inserted into. `is_group_member` is declared `stable`,
-- so it reads the snapshot from the start of the statement and cannot see the
-- row currently being inserted. It returns false and the SELECT policy denies.
--
-- That matters because the admin's push does an upsert with `.select()`
-- (PostgREST `Prefer: return=representation` -> `INSERT ... RETURNING`), and
-- RETURNING requires the SELECT policy to pass for the new row. `ON CONFLICT
-- DO UPDATE` requires it too. A plain INSERT with neither clause always
-- worked — which is why the tables, the policies, and auth.uid() all looked
-- correct in isolation.
--
-- Fix: compare `admin_id` on the row being checked directly. The membership
-- arm still needs a lookup, but only into group_members, never back into
-- groups, so there is no self-reference and no snapshot problem.
--
-- is_group_member() itself is left alone: the other tables' policies call it
-- as is_group_member(group_id), where the referenced group row already exists
-- and committed, so the self-lookup is sound there.

drop policy if exists groups_select on public.groups;
create policy groups_select on public.groups
  for select to authenticated
  using (
    admin_id = auth.uid()
    or exists (
      select 1
      from public.group_members m
      where m.group_id = public.groups.id
        and m.user_id = auth.uid()
    )
  );
