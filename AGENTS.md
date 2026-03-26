<!-- Generated: 2026-03-26 | Updated: 2026-03-26 -->

# CrownPrix

## Purpose
A Formula 1 racing game for Apple Watch with an iOS companion app. Players steer using the Digital Crown through 24 real-world F1 circuits, competing on Game Center leaderboards with lap times and sector splits.

## Key Files

| File | Description |
|------|-------------|
| `README.md` | Project overview, architecture, track list, requirements |
| `ExportOptions.plist` | App Store Connect distribution settings (team 9ZMW52M7L5) |
| `Info.plist` | Bundle metadata, app category (racing-games) |
| `.env.example` | App Store Connect API credential template |
| `.gitignore` | Git ignore rules |
| `AuthKey_2KR79L4Q68.p8` | App Store Connect API auth key |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `CrownPrix/` | Xcode project containing iOS app, watchOS app, and tests (see `CrownPrix/AGENTS.md`) |
| `scripts/` | Python utilities for Game Center leaderboard management (see `scripts/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- This is a Swift/SpriteKit project targeting watchOS 10.0+ and iOS 17.0+
- Build with Xcode 16.0+ — no CocoaPods or SPM dependencies beyond system frameworks
- The `.env` file contains App Store Connect API credentials — never commit secrets
- Track data lives as preprocessed JSON in the watch app bundle, not raw SVGs

### Testing Requirements
- Run tests via Xcode: `xcodebuild test -scheme CrownPrix -destination 'platform=watchOS Simulator'`
- 34+ tests across 3 test files covering pipeline integrity, physics, persistence, and track geometry
- Set `GENERATE_TRACKS=1` env var to regenerate preprocessed track JSON from SVGs

### Common Patterns
- Singletons for cross-view managers (`GameCenterManager.shared`, `WatchConnectivityManager.shared`)
- Namespace enums for stateless utilities (`TimeFormatter`, `TrackRegistry`, `GameConfig`)
- Final classes for stateful game systems (`PhysicsEngine`, `CollisionSystem`, `SectorDetector`)
- All tracks normalized to 2000-unit coordinate space with 800 sample points

## Dependencies

### External
- SpriteKit — 2D game rendering engine
- GameKit — Game Center leaderboards and authentication
- WatchConnectivity — iOS ↔ watchOS message passing
- SwiftUI — UI framework for both targets

<!-- MANUAL: -->
