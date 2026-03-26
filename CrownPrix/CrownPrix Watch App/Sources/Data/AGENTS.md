<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-26 | Updated: 2026-03-26 -->

# Data

## Purpose
Track registry providing the canonical list of all racing circuits for the watchOS app.

## Key Files

| File | Description |
|------|-------------|
| `TrackRegistry.swift` | Static registry of 24 F1 tracks + 1 dev track (DEBUG only); provides `allTracks`, `track(byId:)`, and `sortedByName` access |

## For AI Agents

### Working In This Directory
- `TrackRegistry` is the watchOS-side equivalent of the iOS `Models/TrackRegistry`
- Dev track (`"dev"`) included only in `#if DEBUG` builds for testing without Game Center
- Leaderboard ID convention: `cp.laptime.{trackId}` — must match Game Center and iOS app
- Adding a new track requires: entry here, SVG in Resources, sector config in SectorConfig, leaderboard via scripts

### Testing Requirements
- `TrackPipelineTests` validates 24 entries (25 in DEBUG), unique IDs and leaderboard IDs

### Common Patterns
- Namespace enum with static computed properties

## Dependencies

### Internal
- `Models/TrackMetadata` — track identity type

### External
- None

<!-- MANUAL: -->
