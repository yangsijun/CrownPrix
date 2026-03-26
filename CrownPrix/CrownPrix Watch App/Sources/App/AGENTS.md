<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-26 | Updated: 2026-03-26 -->

# App

## Purpose
watchOS app entry point and root navigation controller. Manages the screen state machine that drives the user through home, track selection, racing, and results.

## Key Files

| File | Description |
|------|-------------|
| `CrownPrixApp.swift` | @main entry point: activates WatchConnectivity, runs `cleanupInvalidSectorTimes()` on launch |
| `ContentView.swift` | Root state machine using `AppScreen` enum: .home → .trackSelect → .race → .result → .trackLeaderboard, with cached lastTrackId and lastResultData for navigation |

## For AI Agents

### Working In This Directory
- `ContentView` uses an `AppScreen` enum to manage navigation state — all screen transitions go through this
- Navigation flow: Home (START) → TrackSelect (RACE) → Race (lap complete) → Result (Retry/Rankings/Tracks)
- `lastTrackId` and `lastResultData` are cached `@State` for back-navigation without data loss
- WatchConnectivity is activated on app appear, not in init, to ensure proper lifecycle timing

### Testing Requirements
- Navigation flow is visual — verify on simulator that all transitions work
- Ensure `cleanupInvalidSectorTimes()` runs once on cold launch

### Common Patterns
- Enum-based state machine for screen navigation
- `@State` caching of last-used values for seamless back-navigation

## Dependencies

### Internal
- `UI/` — all view screens (HomeView, TrackSelectView, RaceView, ResultView, LeaderboardView)
- `Systems/WatchConnectivityManager` — activated on launch
- `Systems/PersistenceManager` — cleanup on launch

### External
- SwiftUI, WatchKit

<!-- MANUAL: -->
