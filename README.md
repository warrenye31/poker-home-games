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
4. In Signing & Capabilities, pick your own team (or leave it on Automatic)
5. Run on a simulator or device

Re-run `xcodegen generate` any time `project.yml` changes or you add/remove source files.

## What's implemented (MVP)

- **Groups tab** — create/delete groups; each group has its own player roster and session history
- **Start a session** — pick players from the roster (or add new ones on the fly), optionally
  designate one player as the bank, seed everyone with a default buy-in
- **Live session** — track rebuys per player, running pot total
- **End session** — enter final cash-outs, with a live balance check against total buy-ins so a
  typo gets caught before you generate a payout
- **Settlement** — computes the minimal set of payer → payee transfers (or bank-based settlement if
  a bank was used), with a share-sheet summary
- **Sessions / Stats tabs** — scoped to whichever group you last opened, with a switcher to jump
  between groups without going back to the Groups tab
- **Settings** — default buy-in amount, currency

## Not yet built (see the roadmap from planning)

- iCloud/CloudKit sync across your own devices
- Swift Charts leaderboard, mark-as-paid tracking, CSV export
- Custom pixel-level styling to match the black/red mockup exactly — this MVP uses standard
  dark-mode `List`/`Form` styling plus a red accent tint, not fully custom card chrome
