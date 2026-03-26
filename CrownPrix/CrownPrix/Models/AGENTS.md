<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-26 | Updated: 2026-03-26 -->

# Models (iOS)

## Purpose
Shared data types used by both the iOS and watchOS targets. Defines track identity, the canonical track registry, and time formatting utilities.

## Key Files

| File | Description |
|------|-------------|
| `TrackMetadata.swift` | Identifiable/Hashable struct: id, displayName, country, flag, leaderboardId |
| `TrackRegistry.swift` | Static registry of all 24 F1 tracks (+ dev track in DEBUG); provides lookup by ID and sorted access |
| `TimeFormatter.swift` | Namespace enum formatting TimeInterval as `M:SS.mmm` via millisecond-based integer arithmetic |

## For AI Agents

### Working In This Directory
- These files have target membership in both iOS and watchOS — changes affect both apps
- `TrackRegistry.allTracks` is the single source of truth for track enumeration
- Leaderboard ID convention: `cp.laptime.{trackId}` — must match Game Center configuration
- `TimeFormatter` avoids floating-point precision issues by converting to integer milliseconds first
- The dev track (`"dev"`) is only included in `#if DEBUG` builds

### Testing Requirements
- `TrackPipelineTests` validates registry uniqueness (IDs and leaderboard IDs)
- `QATests` validates `TimeFormatter` output

### Common Patterns
- Namespace enums (`TimeFormatter`, `TrackRegistry`) for grouping static utility methods
- `Identifiable` conformance enables direct use in SwiftUI `ForEach`

## Dependencies

### Internal
- Consumed by `GameCenterManager`, `PhoneConnectivityManager`, all views, and watchOS game systems

### External
- Foundation only

<!-- MANUAL: -->
