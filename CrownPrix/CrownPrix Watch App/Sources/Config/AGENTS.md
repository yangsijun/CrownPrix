<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-26 | Updated: 2026-03-26 -->

# Config

## Purpose
Centralized game constants and per-track configuration. All tunable parameters live here — no magic numbers elsewhere in the codebase.

## Key Files

| File | Description |
|------|-------------|
| `GameConfig.swift` | All game constants: steering (maxTurnRate, smoothSpeed, deadZone, curveExponent), speed (max 180, min 70, accel 150), track (roadHalfWidth 16, collisionHalfWidth 20, targetSize 2000, pointCount 800), camera (scale 0.45, lookAhead 36), timing (30 FPS), display (speedScale 12.0) |
| `SectorConfig.swift` | Per-track sector boundaries as fractional positions (sector1End, sector2End) and start offsets for all 24+1 tracks; converts to segment indices via `boundaries(trackId:segmentCount:)` |

## For AI Agents

### Working In This Directory
- `GameConfig` is the single source of truth for all numerical constants — every game system reads from here
- `SectorConfig` defines where each track's 3 sectors begin/end as fractions (0.0–1.0) of the total track length
- `SectorConfig.startOffset` shifts the start/finish line position (e.g., monaco=0.26, baku=0.94)
- After changing any constant, run QA tests to validate GameConfig bounds and pipeline tests for track geometry
- Constants are tuned for 2000-unit track coordinate space

### Testing Requirements
- `QATests` validates GameConfig sanity: speed/turn/width/scale bounds checking
- Pipeline tests depend on `targetTrackSize` and `trackPointCount` — changes cascade

### Common Patterns
- Static struct with `let` constants (immutable at runtime)
- `SectorConfig` uses a dictionary lookup with `TrackLayout` value type

## Dependencies

### Internal
- None — consumed by Game, Pipeline, HUD, Input, and Systems

### External
- Foundation only

<!-- MANUAL: -->
