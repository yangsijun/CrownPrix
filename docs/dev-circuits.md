# Development circuits

Debug builds expose Sepang (`sepang`), Imola (`imola`), and Portimão
(`portimao`) alongside the existing Bahrain-based Dev Circuit. Both watchOS
and iOS registries omit these entries in Release builds. Resources remain
bundled; visibility is controlled by `#if DEBUG` in the registries.

The watch uses the existing offline Game Center mocks for these circuits.
Development IDs are excluded from production score uploads, Supabase sync,
and championship aggregation, including messages from a Debug watch to a
Release phone. Their local lap records remain separate. iOS does not query
live leaderboards for these circuits.

## Geometry sources

| Circuit | Source | Preparation |
| --- | --- | --- |
| Sepang | `RaceCircuitSepang.svg` from CrownPrix commit `0ab90d8` | Restore the historical SVG, sample its curve using SVGPath 1.3.0 at detail 20, reverse its point order, and write a closed polyline SVG. This bakes racing direction into the source. |
| Imola | [coggs/f1_svg/Imola.svg](https://github.com/coggs/f1_svg/blob/main/Imola.svg) | Keep the first, complete circuit path; remove the three colored sector overlays. |
| Portimão | [coggs/f1_svg/Portimao.svg](https://github.com/coggs/f1_svg/blob/main/Portimao.svg) | Keep the first, complete circuit path; remove the three colored sector overlays. |

The exact upstream URL of the historical Sepang SVG is not recorded in the
repository. The coggs SVGs are based on F1 game telemetry.

The existing `TrackPreprocessor` generates each bundled JSON: sample 800
equidistant points, apply three circular moving-average passes, and scale
the longest bounding-box dimension to 2,000 game units. Only the three new
JSON files were generated; existing circuit JSON and authored inner barriers
were preserved. No new packages or alternate runtime pipeline are needed.

All three registry entries use `racingDirectionReversed: false`. Sepang keeps
the historical start offset of `0.70` and sector boundaries `0.352 / 0.689`.
Imola and Portimão start at the telemetry path origin; their sector fractions
come from locating the starts of source sector overlays 2 and 3 on the
800-point path (`0.3675 / 0.69125` and `0.31125 / 0.67125`, respectively).

## Verification and regeneration

`TrackPipelineTests` checks Debug/Release registry visibility, exclusion from
competitive tracks, offline watch mocks, and exact agreement between each
new bundled JSON and the current SVG preprocessing output. Existing geometry
and runtime-loading tests also cover the three new circuits in Debug.

Use the existing `testGeneratePreprocessedJSON` test with `GENERATE_TRACKS=1`
to regenerate data after changing an SVG. That test rewrites **all** tracks:
preserve or regenerate authored `innerBarriers` in Monaco and Canada as its
source comment describes. Run `scripts/find_shortcuts.py` after geometry
changes; the three new circuits require no inner barriers at the current
road width and collision settings.
