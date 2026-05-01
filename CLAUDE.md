# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PokerStack is a native iOS application written in Swift/SwiftUI that helps poker hosts calculate optimal chip distributions for cash games. It has no external dependencies — pure Apple frameworks only.

## Build & Run

This is an Xcode project with only source files in the repository (no `.xcodeproj` committed). Build and run via Xcode IDE or `xcodebuild`:

```bash
# Build (from directory containing .xcodeproj)
xcodebuild build -scheme PokerStack -destination 'platform=iOS Simulator,name=iPhone 15'

# Run tests (none currently exist, but if added)
xcodebuild test -scheme PokerStack -destination 'platform=iOS Simulator,name=iPhone 15'
```

There is no linter, formatter, or test suite configured.

## Architecture

### Data Flow

```
CashSetupView (main screen)
  ├── reads/writes CashSetupStore (UserDefaults persistence)
  ├── reads/writes ChipSetStore (named chip set library)
  ├── calls ChipAllocator.allocate() or ChipAllocator.autoOptimize()
  └── presents ResultsSheetsView with AllocationResult
```

### Core Calculation Engine

**`ChipAllocator.swift`** — stateless enum with two entry points:
- `allocate(chips:players:buyInCents:reservePercent:smallBlindCents:bigBlindCents:)` — manual mode, user specifies denominations
- `autoOptimize(...)` → `AutoOptimizationResult` — tries denomination combinations and picks the highest-scoring one

The allocator reserves a percentage of total chips as bank, distributes the rest equally per player, then scores the result based on blind coverage and playability.

**`AutoDenominationAssigner.swift`** — given a blind size and player count, suggests which denominations from `ChipAllocator.availableDenoms` to assign to each chip color. Available denominations (in cents): `10, 25, 50, 100, 500, 1000, 2500, 5000, 10000, 50000`.

**`Money.swift`** — two utility functions used throughout:
- `Money.cents(from: String)` — parses "$1.25" or ".10" → Int cents
- `Money.format(cents: Int)` — formats 125 → "$1.25"

### Data Models

**`ChipType`** — identified by `UUID`, has `colorName: String`, `denominationCents: Int`, `quantity: Int`. Valid colors: White, Red, Blue, Green, Black, Purple, Yellow, Orange, Pink, Brown, Gray.

**`AllocationResult`** — output of `ChipAllocator`:
- `perPlayer: [ChipType: Int]` — chips per player
- `bankLeft: [ChipType: Int]` — chips kept in bank
- `feasible: Bool` — whether buy-in is achievable with given chips
- `score: Int` — higher is better (used for auto-optimization)
- `blindPostsPossible: Int` — playability metric

### State / Persistence

**`CashSetupStore`** — `@Observable` class, persists current game params (players, buy-in, reserve %, blinds) to `UserDefaults` as JSON.

**`ChipSetStore`** — `@Observable` class, persists named chip sets (a saved `[ChipType]` inventory with metadata) to `UserDefaults` as JSON.

No Core Data, no iCloud, no networking.

### UI Structure

**`CashSetupView.swift`** — the main and only persistent screen. Contains:
- Game parameter inputs (players, buy-in, reserve %, small/big blind)
- Chip inventory table (add/edit/delete rows via `EditChipRowSheetView`)
- Mode toggle: Manual denominations vs. Auto-assign
- Calculate button → async `Task` calling `ChipAllocator` → presents `ResultsSheetsView`

**`ResultsSheetsView.swift`** — modal sheet showing allocation results, per-player chip breakdown, bank remainder, confidence rating (Optimal/Strong/Playable), and option to save the chip set.

**`ChipSetsView.swift`** — sheet for browsing and loading saved chip sets.

### Design System

`AppColors.swift` defines the palette used throughout:
- Background: dark green-tinted (`#0D1510`)
- Card surfaces: `#1E2723`
- Accent: gold (`#D9A50D`)

`CardView.swift` is the standard container — use it for any new card-style UI sections.
