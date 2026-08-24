# Poker Night

SwiftUI + SwiftData iOS app for tracking poker home game buy-ins, cash-outs, and settlements.
No gameplay tracking, no payments, no ads.

## Requirements

- A Mac with Xcode 15+ (targets iOS 17)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — this project checks in
  `project.yml` instead of a hand-edited `.xcodeproj`, so there's nothing binary/merge-conflict-prone
  to maintain by hand.

## First-time setup (on a Mac)

1. `brew install xcodegen` (skip if already installed)
2. From this folder: `xcodegen generate`
3. Open `PokerNight.xcodeproj`
4. In Signing & Capabilities for the `PokerNight` target, pick your own team — Automatic signing
   should create the `group.com.waylabsinc.pokernight` App Group container the first time it
   provisions the target. If Xcode complains it can't create the App Group automatically, add it
   manually once from the target's Signing & Capabilities tab ("+ Capability" → App Groups →
   `group.com.waylabsinc.pokernight`) before building.
5. Run the `PokerNight` scheme on a simulator or device.

Re-run `xcodegen generate` any time `project.yml` changes or you add/remove source files.

## What's implemented (MVP)

- **Groups tab** — create/delete groups; each group has its own player roster and session history.
  The organizer can rename anyone on the roster (Edit → tap a player, or long-press any row);
  the change follows the player through every past session and syncs to anyone they invited
- **Start a session** — set a name, date, location, blinds, and standard buy-in, pick players from
  the roster (or add new ones on the fly), optionally designate one player as the bank, then create
  the session immediately (each player starts with one buy-in; add more from the live session)
- **Edit a session** — change name, date, location, blinds, standard buy-in, or bank at any point
  from the live session or settlement screen
- **Live session** — track rebuys per player, running pot total, haptic feedback on each buy-in
- **End session** — enter final cash-outs, with a live balance check against total buy-ins (and a
  success haptic when it balances) so a typo gets caught before you generate a payout
- **Settlement** — for a no-bank game, the provably fewest payer → payee transfers: it finds the
  largest number of groups that can settle among themselves before matching anyone up, so a pair
  who are exactly square with each other never gets dragged into the rest of the table. (A bank
  session instead lists the real cash flow, buy-in and cash-out per player.) Share-sheet summary
  included
- **Sessions / Stats tabs** — scoped to whichever group you last opened, with a switcher to jump
  between groups without going back to the Groups tab
- **Settings** — default buy-in amount, currency
- **First-run onboarding** — a skippable 3-screen walkthrough shown once when there are zero groups
- **Card-based UI** — charcoal cards with a red left-edge accent across Groups, Session history,
  Sessions, and Stats, replacing the earlier stock `List` row look
- **Group sharing** — an admin can publish a group to Supabase and share a join code; other
  devices join as read-only viewers with pull-to-refresh and best-effort Realtime updates
- **Invites** — an "Invite your friends" banner on the group screen opens a sheet with the join code
  as a tap-to-copy hero, the three steps the other person follows, and a one-tap invite message that
  carries the App Store link alongside the code
- **Standings screenshot** — the group screen's share button renders the roster to an image (no join
  code in it) for pasting into the group chat
- **App icon** — a black/red poker-chip-and-spade icon (generated programmatically; see
  `PokerNight/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`)

## Support & Legal

- **[Support](https://warrenye31.github.io/poker-home-games/support.html)** — FAQ and how to contact us
- **[Privacy Policy](https://warrenye31.github.io/poker-home-games/privacy.html)**
- **[Terms of Use](https://warrenye31.github.io/poker-home-games/terms.html)**

All are served by GitHub Pages from `docs/`, which is also where the App Store Connect listing
points. The `.html` sources render as raw markup if you open them in the repo file browser — use the
links above to read them as pages.

Questions or issues: <pokernight@waylabs.com>
