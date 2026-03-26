<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-26 | Updated: 2026-03-26 -->

# Views (iOS)

## Purpose
SwiftUI views for the iOS companion app. Provides Game Center authentication gate, track list with personal bests, detailed leaderboards with sector records, and an about sheet.

## Key Files

| File | Description |
|------|-------------|
| `ContentView.swift` | Root view: shows TrackListView if Game Center authenticated, sign-in prompt otherwise; hosts AboutView sheet |
| `TrackListView.swift` | Main hub: lists all 24 tracks with user's rank (P1–PN) and best lap time, concurrent loading via TaskGroup |
| `LeaderboardView.swift` | Single-track detail: top 50 entries, local player highlight, purple sector records (3 sectors) |

## For AI Agents

### Working In This Directory
- Views observe `GameCenterManager` via `@EnvironmentObject` for auth state and leaderboard data
- `TrackListView` uses `withTaskGroup` to load all leaderboards concurrently — efficient but be aware of rate limits
- Rank color coding: purple (P1), green (P2–P3), yellow (P4–P10), gray (P11+)
- Sector times display in `SS.mmm` format (no minutes, sectors are always <60s)
- `ContentView` includes `AboutView` with dynamic app icon loading from `CFBundleIcons`

### Testing Requirements
- Game Center features require sandbox account authentication
- Leaderboard data is live from Game Center — no mock data layer on iOS

### Common Patterns
- `@State` for local view data, `@Binding` for parent-child coordination
- `NavigationStack` with `NavigationLink` for drill-down navigation
- Pull-to-refresh on list views via `.refreshable`
- `async let` for concurrent data fetching in `LeaderboardView`

## Dependencies

### Internal
- `GameCenterManager` — all leaderboard queries and auth state
- `Models/TrackRegistry` — track enumeration
- `Models/TimeFormatter` — lap time display formatting

### External
- SwiftUI, GameKit

<!-- MANUAL: -->
