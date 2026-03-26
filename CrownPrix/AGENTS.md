<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-26 | Updated: 2026-03-26 -->

# CrownPrix (Xcode Project)

## Purpose
Xcode project container housing all three targets: the iOS companion app, the watchOS racing game, and the test suite. Also contains the Xcode project configuration and build schemes.

## Key Files

| File | Description |
|------|-------------|
| `Info.plist` | Shared project-level plist (app category, encryption, scene config) |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `CrownPrix/` | iOS companion app — Game Center gateway and leaderboard browser (see `CrownPrix/AGENTS.md`) |
| `CrownPrix Watch App/` | watchOS racing game — primary game target with SpriteKit engine (see `CrownPrix Watch App/AGENTS.md`) |
| `CrownPrixTests/` | Unit and integration tests for pipeline, physics, and persistence (see `CrownPrixTests/AGENTS.md`) |
| `CrownPrix.xcodeproj/` | Xcode project file with build settings and schemes |

## For AI Agents

### Working In This Directory
- Do not manually edit `CrownPrix.xcodeproj/project.pbxproj` — use Xcode for target/file membership changes
- iOS and watchOS targets share `TrackMetadata`, `TrackRegistry`, and `TimeFormatter` source files
- The watchOS app is the primary game; iOS is a companion for Game Center and leaderboard viewing

### Testing Requirements
- Tests are in `CrownPrixTests/` — run via Xcode test action on the watchOS simulator
- Pipeline tests can regenerate track JSON when `GENERATE_TRACKS=1` is set

### Common Patterns
- Shared code between targets lives in the iOS target directory but has membership in both targets
- WatchConnectivity bridges iOS ↔ watchOS communication

## Dependencies

### Internal
- All subdirectories are tightly coupled through shared models and Game Center integration

### External
- SpriteKit, GameKit, WatchConnectivity, SwiftUI (system frameworks)

<!-- MANUAL: -->
