<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-26 | Updated: 2026-03-26 -->

# Sources

## Purpose
All Swift source code for the watchOS racing game, organized into 10 functional subdirectories covering the full stack from app entry point through game engine to UI.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `App/` | App entry point and root navigation state machine (see `App/AGENTS.md`) |
| `Config/` | Centralized game constants and per-track sector boundaries (see `Config/AGENTS.md`) |
| `Data/` | Track registry for watchOS (see `Data/AGENTS.md`) |
| `Game/` | SpriteKit game engine: physics, collision, lap/sector detection, rendering (see `Game/AGENTS.md`) |
| `HUD/` | In-race overlay: timer, minimap, wrong-way indicator (see `HUD/AGENTS.md`) |
| `Input/` | Digital Crown input handler (see `Input/AGENTS.md`) |
| `Models/` | Core data structures: track data, race results, sector colors (see `Models/AGENTS.md`) |
| `Pipeline/` | Track processing: SVG parsing → polyline sampling → normalization (see `Pipeline/AGENTS.md`) |
| `Systems/` | Manager singletons: Game Center, persistence, haptics, watch connectivity (see `Systems/AGENTS.md`) |
| `UI/` | SwiftUI views: home, track select, race, results, leaderboard, rankings (see `UI/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- Code flows top-down: `App` → `UI` → `Game` → `Systems`
- `Game/GameScene.swift` is the orchestrator — it owns all game subsystems and runs the 30 FPS update loop
- All magic numbers live in `Config/GameConfig.swift` — never hardcode game constants in other files
- Models are immutable value types; Systems are stateful singletons; Game components are final classes

### Architecture Layers
1. **Models** — immutable value types (no dependencies)
2. **Config** — static constants (depends on nothing)
3. **Data** — track registry (depends on Models)
4. **Pipeline** — SVG → game-ready data (depends on Models, Config)
5. **Game** — physics, collision, detection, rendering (depends on Models, Config, Systems)
6. **HUD** — in-race overlays (depends on Config, Models)
7. **Input** — crown handling (depends on Config)
8. **Systems** — persistence, Game Center, connectivity, haptics (depends on Models)
9. **UI** — SwiftUI navigation and views (depends on everything above)
10. **App** — entry point and state machine (depends on UI, Systems)

### Common Patterns
- Enums as namespaces for static utilities
- Final classes for stateful systems
- Circular track indexing with modulo arithmetic
- Segment-based position tracking (not distance-based)

<!-- MANUAL: -->
