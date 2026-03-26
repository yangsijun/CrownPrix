<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-26 | Updated: 2026-03-26 -->

# CrownPrixTests

## Purpose
Unit and integration tests covering the track processing pipeline, game physics, collision geometry, persistence, and configuration validation. 34+ tests across 3 test files.

## Key Files

| File | Description |
|------|-------------|
| `CrownPrixTests.swift` | Basic resource integrity — verifies SVG files load via BundleHelper |
| `TrackPipelineTests.swift` | 14 tests: SVG existence, parsing, polyline sampling, preprocessing, track registry uniqueness, closed-loop validation |
| `QATests.swift` | 20 tests: track loading, geometry bounds, crown input response, GameConfig sanity, collision math, persistence round-trips, time formatting |

## For AI Agents

### Working In This Directory
- Tests run on the watchOS simulator via Xcode test action
- `TrackPipelineTests` validates the full SVG → JSON pipeline for all 24 tracks
- `QATests` validates runtime invariants (no live game loop, static assertions)
- Set `GENERATE_TRACKS=1` environment variable to trigger JSON track regeneration during test runs

### Testing Requirements
- All tests must pass before merging changes to track data, physics, or pipeline code
- Pipeline tests are the safety net for track geometry — run after any SVG or preprocessor changes
- QA tests validate GameConfig bounds — run after tuning any game constants

### Common Patterns
- `XCTAssertEqual` with tolerances for floating-point geometry comparisons
- Tests cover edge cases: Suzuka dual-path merge, Monaco closed-loop, zero-length segments
- Track registry tests verify uniqueness of both track IDs and leaderboard IDs

## Dependencies

### Internal
- `CrownPrix Watch App/Sources/Pipeline/` — track processing code under test
- `CrownPrix Watch App/Sources/Config/` — GameConfig constants validated by QA tests
- `CrownPrix Watch App/Resources/` — SVG and JSON track data loaded during tests

### External
- XCTest — Apple's testing framework

<!-- MANUAL: -->
