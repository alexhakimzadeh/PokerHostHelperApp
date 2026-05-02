# PokerHost / PokerStack Context

## What This App Is

This directory contains a small native SwiftUI iOS app for hosting poker cash games.

Primary user goal:
- Enter player count, buy-in, reserve %, blinds, and available chip inventory.
- Calculate an exact per-player starting stack.
- Keep enough chips in the bank for rebuys.
- Save and reload chip-set presets.

The product language inside the UI is mostly "Poker Stack" / "PokerStack", while the folder and repo naming use "PokerHost" / "PokerHostHelper".

## Current Entry Point

- App entry is [`PokerHostHelperApp.swift`](/Users/alexhakimzadeh/Desktop/Code/PokerHostHelper/PokerHost/PokerHostHelperApp.swift).
- The `@main` app struct is currently named `YourAppNameApp`, which looks like a leftover placeholder.
- The app launches directly into `CashSetupView`; `ContentView.swift` is an unused SwiftUI template stub.

## Main User Flow

Everything centers around [`Views/CashSetupView.swift`](/Users/alexhakimzadeh/Desktop/Code/PokerHostHelper/PokerHost/Views/CashSetupView.swift).

Screen sections:
- Header and top action buttons (`New Setup`, `Save Set`, `Chip Sets`, `Help`).
- Step 1: game setup (`players`, `buyInText`, `reservePercent`).
- Step 2: blinds (`bigBlindCents`, derived `smallBlindCents`).
- Recommended denomination chips for the chosen blind level.
- Step 3: chip inventory with manual or auto denomination mode.
- Chip bank total, validation messages, and `Calculate Stacks`.

Important behavior:
- Most state changes auto-save via `CashSetupStore`.
- `calculate()` normalizes chip quantities from text state, parses the buy-in, then runs the allocator off the main thread with `Task.detached`.
- In auto mode, the optimizer may rewrite chip denominations before presenting results.
- Results open in a modal sheet and include confidence messaging, metrics, bank-left counts, and chip visualization.

## Core Domain Model

- [`Models/ChipType.swift`](/Users/alexhakimzadeh/Desktop/Code/PokerHostHelper/PokerHost/Models/ChipType.swift)
  Defines a chip color row with `id`, `colorName`, `denominationCents`, and `quantity`.

- [`Persistence/CashSetupStore.swift`](/Users/alexhakimzadeh/Desktop/Code/PokerHostHelper/PokerHost/Persistence/CashSetupStore.swift)
  Defines:
  - `SavedChipRow`
  - `SavedCashSetup`
  - `CashSetupStore`

- [`Persistence/ChipSetStore.swift`](/Users/alexhakimzadeh/Desktop/Code/PokerHostHelper/PokerHost/Persistence/ChipSetStore.swift)
  Defines:
  - `SavedNamedChipSet`
  - `ChipSetStore`

## Persistence

Persistence is `UserDefaults`-backed, JSON-encoded.

Keys:
- `PokerStack.savedCashSetup`
- `PokerStack.savedChipSets`

What is persisted:
- Current setup: players, buy-in text, reserve %, big blind, denomination mode, and current chips.
- Saved chip sets: named inventories, stored with `createdAt`, sorted newest-first on load.

## Calculation Logic

Primary allocator:
- [`Logic/ChipAllocator.swift`](/Users/alexhakimzadeh/Desktop/Code/PokerHostHelper/PokerHost/Logic/ChipAllocator.swift)

### Manual Mode

`allocate(...)`:
- Filters to chips with positive quantity and denomination.
- Applies reserve % per chip color by subtracting `Int(Double(quantity) * reservePercent)`.
- Requires enough remaining total chip value to cover `players * buyIn`.
- Uses DFS/backtracking to find an exact per-player combination.
- Rejects stacks that cannot make the small blind exactly.
- Scores valid allocations for playability, favoring:
  - more exact small-blind chips
  - more low chips
  - more medium chips
  - more blind posts possible
- Penalizes oversized denominations and chip counts far from a target stack size.

### Auto Mode

`optimizeAuto(...)`:
- Builds a denomination pool from blind level and buy-in.
- Tries unique denomination assignments across active chip colors.
- Calls manual `allocate(...)` for each candidate assignment.
- Returns the highest-scoring feasible result.

### Failure Messaging

The allocator builds dynamic, user-readable suggestions when no solution is found, such as:
- lower reserve %
- lower buy-in
- reduce players
- add more low denominations
- add a denomination equal to the small blind

## Other Important Views

- [`Views/ResultsSheetsView.swift`](/Users/alexhakimzadeh/Desktop/Code/PokerHostHelper/PokerHost/Views/ResultsSheetsView.swift)
  Results modal. Shows allocation, confidence label, metrics, assigned denominations in auto mode, and bank-left inventory.

- [`Views/ChipSetsView.swift`](/Users/alexhakimzadeh/Desktop/Code/PokerHostHelper/PokerHost/Views/ChipSetsView.swift)
  Save/load/delete named chip sets.

- [`Views/EditChipRowSheetView.swift`](/Users/alexhakimzadeh/Desktop/Code/PokerHostHelper/PokerHost/Views/EditChipRowSheetView.swift)
  Modal editor for a single chip row.

- [`Views/HelpAboutView.swift`](/Users/alexhakimzadeh/Desktop/Code/PokerHostHelper/PokerHost/Views/HelpAboutView.swift)
  Basic in-app usage guide.

- [`Views/ChipVisualView.swift`](/Users/alexhakimzadeh/Desktop/Code/PokerHostHelper/PokerHost/Views/ChipVisualView.swift)
  Visual row of chip circles for result stacks.

## Design / UI System

- [`Design/AppColors.swift`](/Users/alexhakimzadeh/Desktop/Code/PokerHostHelper/PokerHost/Design/AppColors.swift)
  Dark table-like palette with gold accent.

- [`Design/CardView.swift`](/Users/alexhakimzadeh/Desktop/Code/PokerHostHelper/PokerHost/Design/CardView.swift)
  Shared card wrapper for most sections.

Formatting is consistent with a dark, card-based SwiftUI layout. The app feels like a focused single-screen utility rather than a multi-screen product.

## Utility

- [`Utils/Money.swift`](/Users/alexhakimzadeh/Desktop/Code/PokerHostHelper/PokerHost/Utils/Money.swift)
  Parses buy-in text into cents and formats cents as currency strings.

## Things To Remember Later

- There is visible project churn in `git status`; avoid reverting unrelated work.
- `ContentView.swift` appears unused.
- `removeChipRow(id:)` exists in `CashSetupView` but does not appear wired into the visible UI.
- `AutoDenominationAssigner.swift` exists, but the active auto flow appears to use `ChipAllocator.optimizeAuto(...)` instead.
- There are naming leftovers from project setup:
  - app struct name `YourAppNameApp`
  - some file headers still mention other file names or the old app name
- Saved chip rows with denomination `200` are coerced back to `100` when loading/applying a setup. That looks intentional as a compatibility patch, but it is worth preserving or revisiting carefully.

## Suggested Starting Points For Future Work

- For behavior changes, start in [`Views/CashSetupView.swift`](/Users/alexhakimzadeh/Desktop/Code/PokerHostHelper/PokerHost/Views/CashSetupView.swift) and [`Logic/ChipAllocator.swift`](/Users/alexhakimzadeh/Desktop/Code/PokerHostHelper/PokerHost/Logic/ChipAllocator.swift).
- For save/load bugs, inspect [`Persistence/CashSetupStore.swift`](/Users/alexhakimzadeh/Desktop/Code/PokerHostHelper/PokerHost/Persistence/CashSetupStore.swift) and [`Persistence/ChipSetStore.swift`](/Users/alexhakimzadeh/Desktop/Code/PokerHostHelper/PokerHost/Persistence/ChipSetStore.swift).
- For UI polish, most reusable styling lives in [`Design/AppColors.swift`](/Users/alexhakimzadeh/Desktop/Code/PokerHostHelper/PokerHost/Design/AppColors.swift) and [`Design/CardView.swift`](/Users/alexhakimzadeh/Desktop/Code/PokerHostHelper/PokerHost/Design/CardView.swift).
