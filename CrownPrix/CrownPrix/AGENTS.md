<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-26 | Updated: 2026-03-26 -->

# CrownPrix (iOS App)

## Purpose
iOS companion app that serves as the Game Center gateway and leaderboard browser. Not a playable game — it authenticates with Game Center, relays scores from the watch, and displays competitive standings across all 24 tracks.

## Key Files

| File | Description |
|------|-------------|
| `CrownPrixApp.swift` | App entry point — initializes Game Center auth, activates Watch Connectivity, enforces dark theme |
| `GameCenterManager.swift` | Singleton managing all Game Center operations: auth, score submission, leaderboard queries, sector records |
| `PhoneConnectivityManager.swift` | WCSession delegate bridging watch ↔ phone messaging with sendMessage + userInfo fallback |
| `CrownPrix.entitlements` | App entitlements configuration |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `Models/` | Shared data types: TrackMetadata, TrackRegistry, TimeFormatter (see `Models/AGENTS.md`) |
| `Views/` | SwiftUI views: auth gate, track list, leaderboard detail, about sheet (see `Views/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- `GameCenterManager` and `PhoneConnectivityManager` are singletons accessed via `.shared`
- Score encoding: lap times stored as milliseconds (Int) in Game Center (×1000 on submit, ÷1000 on read)
- WatchConnectivity uses two channels: `sendMessage` (synchronous with reply) and `transferUserInfo` (async fallback)
- All Game Center operations are async/await — wrap in `Task` blocks when called from delegate callbacks
- Logging prefixes: `[GC]` for Game Center, `[WC-Phone]` for connectivity

### Testing Requirements
- Game Center features require a signed-in sandbox account
- WatchConnectivity requires a paired watch simulator or device

### Common Patterns
- `@Published` properties on ObservableObject managers drive SwiftUI reactivity
- `TaskGroup` for concurrent leaderboard loading across all tracks
- Dictionary serialization (`[String: Any]`) for WatchConnectivity message payloads
- Guard-heavy defensive validation in message handlers

## Dependencies

### Internal
- `Models/TrackRegistry` — canonical track list for leaderboard ID resolution
- `Models/TimeFormatter` — consistent time display formatting
- `Views/` — UI layer consuming manager state

### External
- GameKit — Game Center authentication and leaderboards
- WatchConnectivity — iOS ↔ watchOS bidirectional messaging

<!-- MANUAL: -->
