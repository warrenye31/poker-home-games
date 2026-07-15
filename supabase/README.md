# Supabase setup (Phase 1)

One-time setup to back the group-sharing feature. Everything here is done in the
Supabase dashboard for the project you already created.

## 1. Enable Anonymous sign-ins

The app never shows a sign-up screen — each device authenticates invisibly with
an anonymous user. You must turn this on:

**Authentication → Sign In / Providers → Anonymous sign-ins → Enable.**

(Optional but recommended: Authentication → Rate limits — the anonymous sign-in
limit defaults are fine for a small group app.)

## 2. Run the schema migrations

Open **SQL Editor → New query** and run **every** file in
[`migrations/`](migrations/) in numeric order — paste the entire contents of
each, **Run**, then move to the next:

| Migration | What it adds |
| --- | --- |
| [`0001_init.sql`](migrations/0001_init.sql) | The `groups`, `players`, `sessions`, `session_entries`, and `group_members` tables, the `join_group_with_code()` RPC, all Row Level Security policies, and the Realtime publication. |
| [`0002_admin_player_claim.sql`](migrations/0002_admin_player_claim.sql) | `groups.admin_player_id`, reserving the group creator's own player identity. |
| [`0003_fix_groups_select_self_lookup.sql`](migrations/0003_fix_groups_select_self_lookup.sql) | Fixes `groups_select`, which made sharing fail for **every** group. Required. |

All of them are idempotent (`create table if not exists`, `create or replace
function`, `drop policy if exists` before each `create policy`), so re-running
the whole set against an existing project is safe and is the quickest way to
repair a project that has drifted.

> **Run all of them.** A project with only `0001` looks completely healthy — the
> tables exist, the RPC answers, the policies are all present and correct — and
> sharing still fails 100% of the time, reporting itself as
> `42501: new row violates row-level security policy` (missing `0003`) or
> `PGRST204: could not find the 'admin_player_id' column` (missing `0002`).
> Neither error names the migration you're missing. This list is the checklist.

## 3. Put the credentials in the app (not in git)

From **Project Settings → API**, copy:

- **Project URL**  → `SupabaseURL`
- **anon public** key → `SupabaseAnonKey`  ← the *anon* key, **never** service_role

Copy `PokerNight/Config/SupabaseConfig.example.plist` to
`PokerNight/Config/SupabaseConfig.plist` and fill those two values in. That file
is gitignored, so the secrets never get committed.

## 4. Regenerate the Xcode project

The Supabase Swift package was added to `project.yml`. Regenerate and open:

```sh
xcodegen generate
open PokerNight.xcodeproj   # let SPM resolve the Supabase package on first open
```

## Security notes

- Only the **anon** key is used, and only from the gitignored plist. The
  `service_role` key is never referenced anywhere in the app or repo.
- RLS enforces: read = group admin or anyone who joined with the code; all
  writes = group admin only. The anon key is safe to ship in the app because
  RLS — not the key — is what gates data access.
