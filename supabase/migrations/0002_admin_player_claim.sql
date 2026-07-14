-- PokerNight — Phase 3 follow-up: reserve the group creator's own identity
-- ==========================================================================
-- Paste into the Supabase SQL Editor and Run, after 0001_init.sql.
--
-- Local player "claiming" (Phase 3) is otherwise entirely client-side and
-- non-exclusive — any viewer can claim any player, and multiple viewers can
-- claim the same one, because there's nothing to reserve. The one exception:
-- the group creator's own identity. It would be actively wrong for a random
-- viewer to also claim to be the host, so that single player id is recorded
-- server-side and every device checks it before letting someone claim it.
--
-- No new RLS policy is needed: `admin_player_id` is just another column on
-- `groups`, already covered by the existing groups_update policy (admin-only).

alter table public.groups
  add column if not exists admin_player_id uuid references public.players (id) on delete set null;
