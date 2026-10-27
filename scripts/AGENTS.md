<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-26 | Updated: 2026-03-26 -->

# scripts

## Purpose
Python utilities for managing Game Center leaderboards via the App Store Connect API. Used during project setup and maintenance, not at runtime.

## Key Files

| File | Description |
|------|-------------|
| `create_leaderboards.py` | Creates 96 Game Center leaderboards (24 lap times + 72 sector times) with en-US localization |
| `set_score_range.py` | Sets min/max score ranges on leaderboards; destructive — deletes out-of-range scores |

## For AI Agents

### Working In This Directory
- Scripts require `.env` in project root with: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`, `ASC_APP_ID`
- Uses JWT-based auth against the App Store Connect API
- `set_score_range.py` is dry-run by default — requires `--apply` flag to execute changes
- Score format is `ELAPSED_TIME_CENTISECOND` with `ASC` sort order (lower is better)

### Testing Requirements
- Run with `--filter` to target specific leaderboards (e.g., `--filter "cp.sector."`)
- Always preview `set_score_range.py` output before applying (destructive operation)

### Common Patterns
- Leaderboard naming: `cp{gen}.laptime.{trackId}` for lap times, `cp{gen}.sector.{trackId}.{0|1|2}` for sectors (generation 1 used the legacy `cp.` prefix; must match `LeaderboardIDs.generation` in the app)
- `create_leaderboards.py --generation N` creates a new generation; `archive_leaderboards.py` retires an old one after the release replacing it is live
- Default score range: 1–600000 centiseconds

## Dependencies

### Internal
- `.env` in project root for API credentials
- `~/.appstoreconnect/private_keys/AuthKey_2KR79L4Q68.p8` (via `ASC_KEY_PATH`) for JWT signing

### External
- `PyJWT` — JWT token generation
- `requests` — HTTP client
- `cryptography` — Key parsing for JWT
- `python-dotenv` — Environment variable loading

<!-- MANUAL: -->
