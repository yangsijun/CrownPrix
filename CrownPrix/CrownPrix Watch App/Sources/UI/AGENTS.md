<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-26 | Updated: 2026-03-26 -->

# UI

## Purpose
SwiftUI views for the watchOS app covering the full user journey: home screen, track selection with visual previews, race wrapper, post-race results with sector analysis, leaderboard browsing, and rankings list.

## Key Files

| File | Description |
|------|-------------|
| `HomeView.swift` | Title screen with "Crown Prix" branding, Game Center auth reminder, and START button |
| `TrackSelectView.swift` | Vertical-paging TabView of all tracks: SVG outline with direction arrow, name (MarqueeText), country, best time, rank color |
| `RaceView.swift` | SpriteView wrapper for GameScene: Digital Crown rotation binding (-1 to 1), long-press pause/retire (0.5s), onLapComplete callback |
| `ResultView.swift` | Post-race: large lap time, 3 sector cards with color backgrounds, P1/personal-best comparison with ±gap, retry/tracks/rankings buttons |
| `LeaderboardView.swift` | Top 10 leaderboard entries with local player highlight, purple sector records section (3 sectors), loading/error states |
| `RankingsListView.swift` | All-tracks list with rank and time per track, concurrent TaskGroup loading, Game Center sync button (30s timeout) |
| `MarqueeText.swift` | Horizontally scrolling text for long track names, linear animation with 1.5s pause before loop |
| `TimeFormatter.swift` | Formats TimeInterval as "M:SS.mmm" via integer millisecond arithmetic |

## For AI Agents

### Working In This Directory
- Views are driven by the `AppScreen` state machine in `App/ContentView.swift`
- `RaceView` is the bridge between SwiftUI and SpriteKit — binds `.digitalCrownRotation` to `GameScene.crownRotation`
- `TrackSelectView` loads track JSON in background tasks and syncs Game Center best times on appear
- Rank color coding (consistent across app): purple (P1), green (P2–P3), yellow (P4–P10), secondary (>P10)
- `ResultView` determines title by comparing lap time: vs global best (purple "FASTEST LAP!!"), vs personal best (green "NEW RECORD!"), else (yellow "FINISH")
- `RankingsListView` uses `withTaskGroup` for concurrent leaderboard loading across all tracks

### Testing Requirements
- Visual verification on watchOS simulator
- Test all navigation transitions: Home → TrackSelect → Race → Result → back paths
- Verify MarqueeText scrolling for long track names (e.g., "Autódromo Hermanos Rodríguez")

### Common Patterns
- `@State` for local view data, `@ObservedObject` for shared managers
- `.task` modifier for async data loading on view appear
- `NavigationStack` with programmatic navigation
- Pull-to-refresh via `.refreshable` on list views
- Conditional rendering based on Game Center authentication state

## Dependencies

### Internal
- `Game/GameScene` — SpriteKit scene wrapped by RaceView
- `Systems/GameCenterManager` — leaderboard queries and auth state
- `Systems/PersistenceManager` — local best times
- `Data/TrackRegistry` — track enumeration
- `Pipeline/TrackLoader` — track JSON loading for previews
- `Models/` — RaceCompletionData, TrackMetadata, SectorColor

### External
- SwiftUI — all views and navigation
- SpriteKit — SpriteView in RaceView
- WatchKit — Digital Crown input

<!-- MANUAL: -->
