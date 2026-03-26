<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-26 | Updated: 2026-03-26 -->

# Systems

## Purpose
Cross-cutting manager singletons handling persistence, Game Center integration, watch-to-phone connectivity, and haptic feedback. These are the app's system-level services consumed by both game logic and UI.

## Key Files

| File | Description |
|------|-------------|
| `GameCenterManager.swift` | ObservableObject singleton: score submission via WatchConnectivity, leaderboard queries, sector record loading, bidirectional best-time sync; includes DEBUG mock data for dev track |
| `PersistenceManager.swift` | UserDefaults wrapper: namespaced keys (`bestTime.{trackId}`, `bestSector.{trackId}.{i}`), new-record detection, sector time cleanup on launch |
| `WatchConnectivityManager.swift` | WCSession delegate singleton: sendMessage with reply handlers, transferUserInfo fallback, auth status sync via applicationContext, 10-second timeout with ResumeOnce lock |
| `HapticsManager.swift` | Static haptic methods: maps game events (wall collision, countdown light, race start, new record) to WKInterfaceDevice haptic patterns |

## For AI Agents

### Working In This Directory
- All managers are singletons accessed via `.shared` — initialized once, persist across app lifecycle
- `GameCenterManager` does NOT call GameKit directly on watchOS — all submissions relay through WatchConnectivityManager to the iOS companion
- Score encoding: lap times as milliseconds (Int), sector times as centiseconds — must match iOS-side decoding
- WatchConnectivity has two channels: `sendMessage` (synchronous, with reply) and `transferUserInfo` (async, fire-and-forget fallback)
- `PersistenceManager.cleanupInvalidSectorTimes()` runs on app launch to purge zero/negative times from prior bugs
- `HapticsManager` is stateless — pure static methods wrapping WKInterfaceDevice
- In DEBUG mode, `GameCenterManager` returns mock data for the dev track (F1 driver names, realistic times)

### Testing Requirements
- `QATests` validates PersistenceManager round-trips and best-time preservation
- Game Center and WatchConnectivity require device/simulator pairing — no unit test mocks
- Verify timeout behavior: 10-second sendMessage timeout with `ResumeOnce` preventing double-resume

### Common Patterns
- Singleton pattern with `static let shared`
- `@Published` on ObservableObject for SwiftUI reactivity (`isAuthenticated`, `isPhoneReachable`)
- `CheckedContinuation` for bridging callback-based WatchConnectivity to async/await
- Namespaced UserDefaults keys for collision-free persistence
- Console logging with prefixes: `[GC]` (Game Center), `[WC]` (connectivity), `[Persist]` (storage)

## Dependencies

### Internal
- `Models/TrackMetadata` — track identity for leaderboard ID resolution
- `Data/TrackRegistry` — track enumeration for bulk operations
- `Config/GameConfig` — referenced for score formatting

### External
- WatchConnectivity — iOS ↔ watchOS messaging
- WatchKit — haptic feedback via WKInterfaceDevice
- Combine — @Published properties

<!-- MANUAL: -->
