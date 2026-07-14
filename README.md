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
4. In Signing & Capabilities (for **both** the `PokerNight` and `PokerNightWidgetExtension`
   targets), pick your own team — Automatic signing should create the `iCloud.com.pokernight.app`
   and `group.com.pokernight.app` App Group containers the first time it provisions each target.
   If Xcode complains it can't create the App Group automatically, add it manually once from the
   target's Signing & Capabilities tab ("+ Capability" → App Groups → `group.com.pokernight.app`)
   before building.
5. Pick the `PokerNight` scheme (not the widget scheme) and run on a simulator or device.
6. To see the home-screen widget: run the app once, open a group so it becomes the "last selected"
   group, then add the widget from the home screen (long-press → Edit Home Screen → +) and pick
   Poker Night's Leaderboard widget.

Re-run `xcodegen generate` any time `project.yml` changes or you add/remove source files.

## What's implemented (MVP)

- **Groups tab** — create/delete groups; each group has its own player roster and session history
- **Start a session** — set a name, date, location, blinds, and standard buy-in, pick players from
  the roster (or add new ones on the fly), optionally designate one player as the bank; a review
  screen then shows the session name and participants with a per-player buy-in count before
  creating the session
- **Edit a session** — change name, date, location, blinds, standard buy-in, or bank at any point
  from the live session or settlement screen
- **Live session** — track rebuys per player, running pot total, haptic feedback on each buy-in
- **End session** — enter final cash-outs, with a live balance check against total buy-ins (and a
  success haptic when it balances) so a typo gets caught before you generate a payout
- **Settlement** — computes the minimal set of payer → payee transfers (or bank-based settlement if
  a bank was used), with a share-sheet summary
- **Sessions / Stats tabs** — scoped to whichever group you last opened, with a switcher to jump
  between groups without going back to the Groups tab
- **Settings** — default buy-in amount, currency
- **First-run onboarding** — a skippable 3-screen walkthrough shown once when there are zero groups
- **Card-based UI** — charcoal cards with a red left-edge accent across Groups, Session history,
  Sessions, and Stats, replacing the earlier stock `List` row look
- **Home-screen widget** — a Leaderboard widget (medium/large) showing standings for whichever
  group you last had open in the app
- **App icon** — a black/red poker-chip-and-spade icon (generated programmatically; see
  `PokerNight/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`)

## Not yet built (see the roadmap from planning)

- Interactive/configurable widget (choosing a group from the widget itself rather than mirroring
  the app's last-selected group)

## A note on this session's changes

The card-row restyle, haptics, and onboarding flow are plain SwiftUI/SwiftData changes consistent
with patterns already used elsewhere in this codebase — reasonably high confidence they build.

The **widget extension is the riskiest addition** and hasn't been build-verified — there's no Mac/
Xcode available in the environment that wrote it. Specifically:

- `project.yml` now declares a second target (`PokerNightWidgetExtension`) sharing
  `PokerNight/Models` and a few `Support` files as source paths across both targets. This is a
  supported XcodeGen pattern, but hasn't been run through `xcodegen generate` here.
- The app and widget now open the same SwiftData store via `groupContainer: .identifier(...)`
  (`PokerNight/Support/SharedModelContainer.swift`) — the shared-store + CloudKit + widget
  combination is the same shape as Apple's "Backyard Birds" sample, but double-check it against
  current SwiftData docs if it throws a container-configuration error at runtime.
- The last-selected group name is persisted to `UserDefaults(suiteName: "group.com.pokernight.app")`
  from `AppState` and read back by the widget's `TimelineProvider` — if group names aren't unique
  across a user's groups this lookup could pick the wrong one, though that's an existing edge case
  (group names aren't enforced unique anywhere in the model).

Worth a real build + widget-on-device pass before relying on it.
