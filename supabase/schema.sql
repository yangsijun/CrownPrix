-- =============================================================
-- Table: lap_times
-- Stores each player's best lap time per track (upsert pattern)
-- =============================================================
CREATE TABLE lap_times (
    player_id   TEXT NOT NULL,
    player_name TEXT NOT NULL DEFAULT '',
    track_id    TEXT NOT NULL,
    lap_time_ms INTEGER NOT NULL CHECK (lap_time_ms > 15000),  -- no sub-15s laps physically possible
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (player_id, track_id)
);

-- Index for the ranking query (per-track, ordered by time)
CREATE INDEX idx_lap_times_track_ranking ON lap_times (track_id, lap_time_ms ASC);

-- =============================================================
-- Table: championship_standings
-- Materialized by trigger; never written to by clients
-- =============================================================
CREATE TABLE championship_standings (
    player_id       TEXT PRIMARY KEY,
    player_name     TEXT NOT NULL DEFAULT '',
    total_points    INTEGER NOT NULL DEFAULT 0,
    track_breakdown JSONB NOT NULL DEFAULT '{}',
    tracks_entered  INTEGER NOT NULL DEFAULT 0,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for leaderboard queries (sorted by total points DESC)
CREATE INDEX idx_standings_ranking ON championship_standings (total_points DESC, tracks_entered DESC);

-- =============================================================
-- Function: recalculate_track_standings
-- Reranks all players on a given track and updates championship_standings.
-- Called by both the upsert trigger and the delete trigger.
-- =============================================================
CREATE OR REPLACE FUNCTION recalculate_track_standings(p_track_id TEXT)
RETURNS VOID AS $$
DECLARE
    r RECORD;
    points_table INTEGER[] := ARRAY[25, 18, 15, 12, 10, 8, 6, 4, 2, 1];
    pts INTEGER;
    player RECORD;
    breakdown JSONB;
    total INTEGER;
    entered INTEGER;
BEGIN
    -- Serialize recalculations per track to prevent deadlocks
    -- when two concurrent submissions target the same track.
    PERFORM pg_advisory_xact_lock(hashtext(p_track_id));

    -- Rank all players on the affected track
    FOR r IN
        SELECT lt.player_id, lt.player_name, lt.lap_time_ms,
               ROW_NUMBER() OVER (ORDER BY lt.lap_time_ms ASC) AS pos
        FROM lap_times lt
        WHERE lt.track_id = p_track_id
    LOOP
        IF r.pos <= 10 THEN
            pts := points_table[r.pos];
        ELSE
            pts := 0;
        END IF;

        -- Upsert into championship_standings
        INSERT INTO championship_standings (player_id, player_name, track_breakdown)
        VALUES (r.player_id, r.player_name, '{}'::jsonb)
        ON CONFLICT (player_id) DO UPDATE SET player_name = EXCLUDED.player_name;

        -- Update this track's entry in the breakdown
        UPDATE championship_standings
        SET track_breakdown = jsonb_set(
                track_breakdown,
                ARRAY[p_track_id],
                jsonb_build_object(
                    'rank', r.pos,
                    'points', pts,
                    'lap_time_ms', r.lap_time_ms
                )
            ),
            updated_at = now()
        WHERE player_id = r.player_id;
    END LOOP;

    -- Recalculate total_points and tracks_entered for all affected players
    FOR player IN
        SELECT cs.player_id, cs.track_breakdown
        FROM championship_standings cs
        WHERE cs.track_breakdown ? p_track_id
    LOOP
        total := 0;
        entered := 0;
        FOR r IN SELECT value FROM jsonb_each(player.track_breakdown)
        LOOP
            total := total + (r.value->>'points')::integer;
            entered := entered + 1;
        END LOOP;
        UPDATE championship_standings
        SET total_points = total, tracks_entered = entered
        WHERE player_id = player.player_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =============================================================
-- Trigger: recalculate championship on INSERT or UPDATE
-- =============================================================
CREATE OR REPLACE FUNCTION trg_recalculate_championship()
RETURNS TRIGGER AS $$
BEGIN
    -- Wrap in exception block so lap_time insert still succeeds
    -- even if recalculation fails
    BEGIN
        PERFORM recalculate_track_standings(NEW.track_id);
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'championship recalculation failed for track %: %', NEW.track_id, SQLERRM;
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_recalculate_championship
    AFTER INSERT OR UPDATE ON lap_times
    FOR EACH ROW
    EXECUTE FUNCTION trg_recalculate_championship();

-- =============================================================
-- Trigger: cleanup/recalculate championship on DELETE
-- DELETE now properly recalculates other players' standings
-- =============================================================
CREATE OR REPLACE FUNCTION trg_cleanup_championship_on_delete()
RETURNS TRIGGER AS $$
BEGIN
    BEGIN
        -- Remove the deleted track from this player's breakdown
        UPDATE championship_standings
        SET track_breakdown = track_breakdown - OLD.track_id,
            updated_at = now()
        WHERE player_id = OLD.player_id;

        -- Check if player has any remaining lap times
        IF NOT EXISTS (SELECT 1 FROM lap_times WHERE player_id = OLD.player_id) THEN
            DELETE FROM championship_standings WHERE player_id = OLD.player_id;
        ELSE
            -- Recalculate this player's totals from remaining breakdown
            UPDATE championship_standings
            SET total_points = COALESCE((
                    SELECT SUM((value->>'points')::integer)
                    FROM jsonb_each(track_breakdown)
                ), 0),
                tracks_entered = COALESCE((
                    SELECT COUNT(*)
                    FROM jsonb_each(track_breakdown)
                ), 0)
            WHERE player_id = OLD.player_id;
        END IF;

        -- Recalculate standings for the track that lost a player
        -- (other players may move up in rank)
        PERFORM recalculate_track_standings(OLD.track_id);
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'championship cleanup failed for track %: %', OLD.track_id, SQLERRM;
    END;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_cleanup_championship
    AFTER DELETE ON lap_times
    FOR EACH ROW
    EXECUTE FUNCTION trg_cleanup_championship_on_delete();

-- =============================================================
-- Row Level Security
-- =============================================================
ALTER TABLE lap_times ENABLE ROW LEVEL SECURITY;
ALTER TABLE championship_standings ENABLE ROW LEVEL SECURITY;

-- lap_times: anyone can read, only the owning player can insert/update their own rows
CREATE POLICY "lap_times_select" ON lap_times FOR SELECT USING (true);
CREATE POLICY "lap_times_insert" ON lap_times FOR INSERT
    WITH CHECK (player_id = current_setting('request.headers')::json->>'x-player-id');
CREATE POLICY "lap_times_update" ON lap_times FOR UPDATE
    USING (player_id = current_setting('request.headers')::json->>'x-player-id');

-- championship_standings: read-only for all clients
CREATE POLICY "standings_select" ON championship_standings FOR SELECT USING (true);

-- =============================================================
-- RPC: upsert_lap_time
-- Used by the Swift client instead of raw upsert, to support
-- ON CONFLICT ... WHERE (only store improvements).
-- =============================================================
CREATE OR REPLACE FUNCTION upsert_lap_time(
    p_player_id TEXT,
    p_player_name TEXT,
    p_track_id TEXT,
    p_lap_time_ms INTEGER
) RETURNS VOID AS $$
BEGIN
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
