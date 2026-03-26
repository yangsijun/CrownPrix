<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-26 | Updated: 2026-03-26 -->

# HUD

## Purpose
In-race heads-up display overlays rendered as SpriteKit nodes attached to the camera's UI layer. Shows lap timer, speed gauge, sector times, track minimap, and wrong-way warning.

## Key Files

| File | Description |
|------|-------------|
| `TimerHUD.swift` | Lap timer (M:SS.mmm), speed gauge (km/h), and 3 sector time labels with color-coded backgrounds |
| `MinimapView.swift` | 75×75 track outline with red car dot and yellow start-line marker, anchored top-right |
| `WrongWayIndicator.swift` | Blinking "WRONG WAY" label (3 Hz) when car heading opposes track direction by >90° |

## For AI Agents

### Working In This Directory
- All HUD elements are children of `CameraController.uiNode` (zPosition 200) — they stay fixed on screen
- `TimerHUD` has three states: running (incrementing), frozen (lap complete, green if PR), stopped
- Speed display uses `GameConfig.displaySpeedScale` (12.0) to convert internal units to km/h
- Sector time format: `SS.mmm` for <60s, `M:SS.mmm` for ≥60s
- MinimapView downsamples track to ~80 points for performance
- WrongWayIndicator compares car heading vs track segment direction using angular difference

### Testing Requirements
- Visual verification on watchOS simulator — no automated HUD tests
- Check sector color backgrounds match: white, yellow, green, purple

### Common Patterns
- Final classes with SpriteKit node hierarchies
- Updated every frame by GameScene with fresh position/speed/time data
- Color constants from `SectorColor` enum

## Dependencies

### Internal
- `Config/GameConfig` — display scale, positioning
- `Models/TrackData`, `Models/TrackPoint` — minimap track outline
- `Models/SectorColor` — sector performance color coding

### External
- SpriteKit — label nodes, shape nodes, sprite rendering

<!-- MANUAL: -->
