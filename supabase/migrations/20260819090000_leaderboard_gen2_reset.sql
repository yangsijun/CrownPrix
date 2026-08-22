-- =============================================================
-- Leaderboard generation 2 reset (anti-cheat)
-- Old app versions could exploit track shortcuts / reverse driving.
-- Block their submissions and wipe previously recorded times.
--
-- Apply this together with the app release that bumps
-- LeaderboardIDs.generation to 2 (it also resets the championship).
-- =============================================================

-- 1. Drop the legacy 4-arg RPC. PostgREST resolves RPCs by name + argument
--    set, so old clients calling the 4-arg form now fail cleanly and can no
--    longer submit lap times.
DROP FUNCTION IF EXISTS upsert_lap_time(TEXT, TEXT, TEXT, INTEGER);

-- 2. Recreate with a generation gate: only clients aware of the current
--    leaderboard generation may submit.
CREATE OR REPLACE FUNCTION upsert_lap_time(
    p_player_id TEXT,
    p_player_name TEXT,
    p_track_id TEXT,
    p_lap_time_ms INTEGER,
    p_client_generation INTEGER
) RETURNS VOID AS $$
BEGIN
    IF p_client_generation IS NULL OR p_client_generation < 2 THEN
        RAISE EXCEPTION 'client generation % is no longer supported',
            COALESCE(p_client_generation, 0);
    END IF;

    INSERT INTO lap_times (player_id, player_name, track_id, lap_time_ms)
    VALUES (p_player_id, p_player_name, p_track_id, p_lap_time_ms)
    ON CONFLICT (player_id, track_id)
    DO UPDATE SET
        player_name = EXCLUDED.player_name,
        lap_time_ms = EXCLUDED.lap_time_ms,
        updated_at = now()
    WHERE lap_times.lap_time_ms > EXCLUDED.lap_time_ms;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Wipe tainted data. TRUNCATE does not fire row-level triggers, so
--    championship_standings is truncated explicitly as well.
TRUNCATE lap_times;
TRUNCATE championship_standings;
