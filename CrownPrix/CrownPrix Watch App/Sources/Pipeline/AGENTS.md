<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-26 | Updated: 2026-03-26 -->

# Pipeline

## Purpose
Multi-stage track processing pipeline that transforms SVG race track files into normalized, game-ready point arrays. Runs at build/test time to produce preprocessed JSON bundles loaded at runtime.

## Key Files

| File | Description |
|------|-------------|
| `TrackPreprocessor.swift` | Orchestrator: regex SVG extraction → parse → sample → smooth (3 iterations) → normalize to 2000-unit space → reverse direction if needed; special Suzuka dual-path merge |
| `SVGTrackParser.swift` | Parses SVG path `d` attributes using SVGPath library, converts cubic Bézier curves to CGPoint arrays with 20-point detail |
| `PolylineSampler.swift` | Arc-length resampling: converts variable-density points to exactly 800 equidistant TrackPoints via cumulative arc-length integration |
| `TrackLoader.swift` | Runtime loader: reads preprocessed JSON from app bundle, applies direction reversal and start offset from SectorConfig |
| `BundleHelper.swift` | Resource resolution: searches subdirectories first, then bundle root for track files |
| `TrackPipelineError.swift` | Custom error enum with descriptive messages for each pipeline failure mode |

## For AI Agents

### Working In This Directory
- Pipeline stages: SVG → CGPoint[] → TrackPoint[800] → smoothed → normalized → JSON
- Suzuka is a special case: two SVG paths merged at closest crossing point with heading alignment
- Smoothing uses circular convolution (window radius=2, 3 iterations) — prevents corner sharpening
- Normalization: centers on centroid, scales so max dimension = `GameConfig.targetTrackSize` (2000)
- All transformations are stateless (enum-based, no mutable state)
- `TrackLoader` applies `SectorConfig.startOffset` rotation at load time (shifts start/finish position)
- Preprocessed JSON lives in `Resources/PreprocessedTracks/` — regenerate with `GENERATE_TRACKS=1` in tests

### Testing Requirements
- `TrackPipelineTests` (14 tests) covers the entire pipeline: SVG existence, parsing, sampling, normalization, closed-loop validation
- Run pipeline tests after any SVG changes or preprocessor modifications
- Verify all 24 tracks normalize to origin-centered, 2000-unit-bounded geometry

### Common Patterns
- Stateless enum namespaces for each pipeline stage
- Closed-loop geometry: modulo indexing for circular track arrays
- Error propagation via custom `TrackPipelineError` enum

## Dependencies

### Internal
- `Config/GameConfig` — target track size (2000), point count (800)
- `Config/SectorConfig` — start offset and direction reversal per track
- `Models/TrackPoint`, `Models/TrackData` — output types

### External
- SVGPath (via SPM) — SVG path parsing
- CoreGraphics — CGPoint geometry

<!-- MANUAL: -->
