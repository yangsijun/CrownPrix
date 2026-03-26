<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-26 | Updated: 2026-03-26 -->

# Models (watchOS)

## Purpose
Core immutable data types for track geometry, race results, and display state. These are the foundation types consumed throughout the game engine, pipeline, and UI layers.

## Key Files

| File | Description |
|------|-------------|
| `TrackPoint.swift` | Codable struct with x/y CGFloat coordinates — the atomic unit of track geometry |
| `TrackData.swift` | Processed track state: [TrackPoint] array + metadata (roadHalfWidth, totalLength, startSegmentIndex, startHeading) |
| `TrackMetadata.swift` | Track identity: id, displayName, country, flag, svgFilename, racingDirectionReversed, leaderboardId |
| `RaceResult.swift` | Historical race record: trackId, lapTime, date |
| `RaceCompletionData.swift` | Race outcome: trackId, lapTime, 3-element sector times array, sector colors |
| `SectorColor.swift` | Enum: white (first), yellow (slower), green (personal best), purple (global best) |

## For AI Agents

### Working In This Directory
- All types are immutable value types (structs/enums) — no mutable state
- `TrackData` is the output of the Pipeline and input to the Game engine
- `TrackMetadata` is shared with iOS target — changes affect both apps
- `RaceCompletionData` carries everything needed for the result screen
- `SectorColor` maps to visual colors in both HUD (SpriteKit) and UI (SwiftUI)
- All Codable types use default synthesis — no custom encoding

### Testing Requirements
- Pipeline tests validate TrackData geometry (normalization, closed loops)
- QA tests validate TrackPoint arrays loaded from JSON

### Common Patterns
- Codable + Equatable conformance for serialization and comparison
- Identifiable conformance where needed for SwiftUI lists

## Dependencies

### Internal
- None — foundation layer with no internal dependencies

### External
- CoreGraphics (CGFloat), Foundation (Codable)

<!-- MANUAL: -->
