<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-26 | Updated: 2026-03-26 -->

# Game

## Purpose
SpriteKit-based game engine core. Contains the main scene orchestrator, physics simulation, collision detection, lap/sector timing, track rendering, camera system, car entity, and race countdown. All subsystems are coordinated by GameScene in a single-threaded 30 FPS update loop.

## Key Files

| File | Description |
|------|-------------|
| `GameScene.swift` | Main orchestrator (SKScene + ObservableObject): owns all subsystems, runs update loop, publishes `crownRotation` and `onLapComplete` callback |
| `PhysicsEngine.swift` | Car dynamics: crown input → steering smoothing → heading/speed/position updates via 1st-order kinematics |
| `CollisionSystem.swift` | Wall detection: nearest-segment search, perpendicular distance check, bounce response with speed reduction |
| `LapDetector.swift` | Lap completion state machine: preStart → racing → halfLap → lapComplete (detects start-line crossing) |
| `SectorDetector.swift` | 3-sector timing with color coding: purple (global best), green (personal best), yellow (slower), white (first attempt) |
| `TrackRenderer.swift` | Converts TrackData to SpriteKit geometry: road polyline, start line, striped curbs with per-track color patterns |
| `CameraController.swift` | Smooth third-person camera with look-ahead offset and heading-aligned rotation |
| `CarNode.swift` | Static factory building red polygon car shape with wheels, cockpit, and wings (visual only) |
| `RaceCountdown.swift` | Pre-race 5-light sequence with haptic feedback, then lights-out start signal |

## For AI Agents

### Working In This Directory
- `GameScene.update()` is the heartbeat — all subsystems are updated sequentially in a specific order
- Update order matters: Physics → Collision → Car position → HUD → Lap/Sector detection → Minimap → WrongWay
- Camera updates in `didSimulatePhysics()` (after rendering) for smooth following
- All constants come from `GameConfig` — never hardcode values here
- `PhysicsEngine` is SpriteKit-independent (uses CoreGraphics only) — can be unit tested in isolation
- `CollisionSystem.currentSegmentIndex` is the shared position state consumed by LapDetector and SectorDetector

### Testing Requirements
- QA tests cover crown input response curves, collision geometry (perpendicular distance), and GameConfig bounds
- No live game loop in tests — all validation is static/mathematical
- After physics tuning changes, verify: speed ranges, turn rates, wall bounce behavior

### Common Patterns
- Final classes for all stateful components (prevents accidental subclassing)
- Segment-based position tracking via `currentSegmentIndex` (not world-space distance)
- Circular modulo arithmetic for closed-loop track indexing
- Callbacks (`onLapComplete`, `onSectorComplete`) for decoupled event handling
- Recovery frames: `isRecovering` flag prevents double-collision in consecutive frames

## Dependencies

### Internal
- `Config/GameConfig` — all tunable constants
- `Config/SectorConfig` — per-track sector boundaries
- `Models/TrackData`, `Models/TrackPoint` — processed track geometry
- `Models/RaceCompletionData`, `Models/SectorColor` — result types
- `Systems/PersistenceManager` — personal best lookups
- `Systems/GameCenterManager` — global best sector times, score submission
- `Systems/HapticsManager` — collision and countdown feedback
- `HUD/TimerHUD`, `HUD/MinimapView`, `HUD/WrongWayIndicator` — overlay updates

### External
- SpriteKit — scene, nodes, rendering
- Combine — `@Published` properties for SwiftUI binding

<!-- MANUAL: -->
