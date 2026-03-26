<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-26 | Updated: 2026-03-26 -->

# CrownPrix Watch App

## Purpose
The primary game target — a 2D top-down F1 racing game for Apple Watch. Players steer with the Digital Crown through real-world circuits rendered via SpriteKit, with lap timing, sector splits, haptic feedback, and Game Center leaderboard integration.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `Sources/` | All Swift source code organized by functional layer (see `Sources/AGENTS.md`) |
| `Resources/` | Track data (preprocessed JSON, SVG originals) and app icon assets |
| `Assets.xcassets/` | Xcode asset catalog (accent color) |

## For AI Agents

### Working In This Directory
- All source code lives under `Sources/` in 10 functional subdirectories
- Track data in `Resources/PreprocessedTracks/` is generated from SVGs via the pipeline (don't hand-edit)
- SVG originals in `Resources/Track/` are the source of truth for track geometry
- The app renders at 30 FPS using SpriteKit with a single-threaded update loop

### Architecture Overview
```
Digital Crown → PhysicsEngine → CollisionSystem → LapDetector/SectorDetector
                     ↓                ↓
                  CarNode        currentSegmentIndex
                     ↓
              CameraController → TimerHUD / MinimapView / WrongWayIndicator
```

### Testing Requirements
- Run tests from the `CrownPrixTests` target
- Track pipeline integrity is validated by 14 dedicated tests
- QA tests cover physics, collision geometry, persistence, and config sanity

### Common Patterns
- GameScene orchestrates all subsystems in a single `update()` pass
- All game constants centralized in `GameConfig` — no magic numbers in game logic
- Tracks normalized to 2000-unit coordinate space with 800 equidistant sample points
- Sector boundaries defined as fractional positions in `SectorConfig`

## Dependencies

### Internal
- iOS companion app for Game Center score submission (via WatchConnectivity)

### External
- SpriteKit — game rendering and scene management
- WatchKit — Digital Crown input, haptics
- WatchConnectivity — score sync with iOS companion
- SwiftUI — navigation UI wrapping SpriteKit scenes

<!-- MANUAL: -->
