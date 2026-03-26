import Supabase
import GameKit

final class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()

    private var client: SupabaseClient

    private init() {
        let url = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
        let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""

        // Guard against empty URL crash
        guard let supabaseURL = URL(string: url), !url.isEmpty else {
            // Create a dummy client that will fail gracefully on all operations
            // This prevents a crash when config is missing (e.g., in previews)
            client = SupabaseClient(
                supabaseURL: URL(string: "https://placeholder.supabase.co")!,
                supabaseKey: "placeholder"
            )
            print("[Supabase] WARNING: Missing SUPABASE_URL or SUPABASE_ANON_KEY in build settings")
            return
        }

        // Set x-player-id header for RLS policies.
        // On first init, GC may not be authenticated yet -- use empty string.
        // updatePlayerID() is called once GC auth completes (see CrownPrixApp).
        let playerId = GKLocalPlayer.local.isAuthenticated ? GKLocalPlayer.local.gamePlayerID : ""
        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: key,
            options: .init(
                global: .init(
                    headers: ["x-player-id": playerId]
                )
            )
        )
    }

    // Called when GC auth completes or account changes.
    // Recreates the client with the new player ID in headers.
    func updatePlayerID(_ playerId: String) {
        let url = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
        let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
        guard let supabaseURL = URL(string: url), !url.isEmpty else { return }

        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: key,
            options: .init(
                global: .init(
                    headers: ["x-player-id": playerId]
                )
            )
        )
        print("[Supabase] updated player ID header: \(playerId)")
    }

    /// Submit a lap time via the upsert_lap_time RPC function.
    /// The RPC function uses ON CONFLICT ... WHERE to only store improvements.
    /// updated_at is handled by DB DEFAULT now(), not client clock.
    func submitLapTime(playerId: String, playerName: String, trackId: String, lapTimeMs: Int) async throws {
        try await client.rpc("upsert_lap_time", params: [
            "p_player_id": AnyJSON(playerId),
            "p_player_name": AnyJSON(playerName),
            "p_track_id": AnyJSON(trackId),
            "p_lap_time_ms": AnyJSON(lapTimeMs)
        ]).execute()
    }

    /// Load top N championship standings
    func loadStandings(limit: Int = 50) async throws -> [ChampionshipEntry] {
        let response: [ChampionshipRow] = try await client
            .from("championship_standings")
            .select()
            .order("total_points", ascending: false)
            .order("tracks_entered", ascending: false)
            .limit(limit)
            .execute()
            .value

        return response.enumerated().map { (index, row) in
            ChampionshipEntry(
                rank: index + 1,
                playerId: row.player_id,
                playerName: row.player_name,
                totalPoints: row.total_points,
                tracksEntered: row.tracks_entered,
                isLocalPlayer: row.player_id == GKLocalPlayer.local.gamePlayerID
            )
        }
    }

    /// Load a specific player's standing
    func loadPlayerStanding(playerId: String) async throws -> ChampionshipEntry? {
        let rows: [ChampionshipRow] = try await client
            .from("championship_standings")
            .select()
            .eq("player_id", value: playerId)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else { return nil }
        let countAbove: Int = try await client
            .from("championship_standings")
            .select("player_id", head: true, count: .exact)
            .gt("total_points", value: row.total_points)
            .execute()
            .count ?? 0
        return ChampionshipEntry(
            rank: countAbove + 1,
            playerId: row.player_id,
            playerName: row.player_name,
            totalPoints: row.total_points,
            tracksEntered: row.tracks_entered,
            isLocalPlayer: true
        )
    }

    /// Sync a single track's GC leaderboard to Supabase.
    /// Called after the local player submits a score — fetches all players
    /// on that track from GC and upserts them into Supabase.
    func syncTrackFromGameCenter(trackId: String) async {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        guard let track = TrackRegistry.track(byId: trackId) else { return }

        do {
            let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [track.leaderboardId])
            guard let lb = leaderboards.first else { return }
            let (_, entries, _) = try await lb.loadEntries(for: .global, timeScope: .allTime, range: NSRange(1...10))

            var synced = 0
            for entry in entries {
                try? await submitLapTime(
                    playerId: entry.player.gamePlayerID,
                    playerName: entry.player.displayName,
                    trackId: trackId,
                    lapTimeMs: entry.score
                )
                synced += 1
            }
            print("[Supabase] syncTrack \(trackId): \(synced) entries synced")
        } catch {
            print("[Supabase] syncTrack \(trackId) failed: \(error)")
        }
    }

    /// Initial backfill: sync all tracks from GC (runs once on first launch).
    func reconcileFromGameCenter() async {
        guard GKLocalPlayer.local.isAuthenticated else { return }

        let flag = "supabase.backfilled.\(GKLocalPlayer.local.gamePlayerID)"
        guard !UserDefaults.standard.bool(forKey: flag) else {
            print("[Supabase] reconcile: already backfilled, skipping")
            return
        }

        print("[Supabase] reconcile: first launch backfill starting")
        for track in TrackRegistry.allTracks {
            await syncTrackFromGameCenter(trackId: track.id)
        }
        UserDefaults.standard.set(true, forKey: flag)
        print("[Supabase] reconcile: backfill complete")
    }
    /// Load a player's full championship detail including per-track breakdown
    func loadPlayerDetail(playerId: String) async throws -> ChampionshipDetail? {
        let rows: [ChampionshipRow] = try await client
            .from("championship_standings")
            .select()
            .eq("player_id", value: playerId)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else { return nil }

        let countAbove: Int = try await client
            .from("championship_standings")
            .select("player_id", head: true, count: .exact)
            .gt("total_points", value: row.total_points)
            .execute()
            .count ?? 0

        let trackResults: [ChampionshipDetail.TrackResult] = (row.track_breakdown ?? [:])
            .map { (trackId, entry) in
                let trackName = TrackRegistry.track(byId: trackId)?.displayName ?? trackId
                let flag = TrackRegistry.track(byId: trackId)?.flag ?? ""
                return ChampionshipDetail.TrackResult(
                    trackId: trackId,
                    trackName: trackName,
                    flag: flag,
                    rank: entry.rank,
                    points: entry.points,
                    lapTimeMs: entry.lap_time_ms
                )
            }
            .sorted { $0.points > $1.points }

        return ChampionshipDetail(
            playerId: row.player_id,
            playerName: row.player_name,
            totalPoints: row.total_points,
            tracksEntered: row.tracks_entered,
            rank: countAbove + 1,
            trackResults: trackResults
        )
    }
}

struct ChampionshipDetail {
    let playerId: String
    let playerName: String
    let totalPoints: Int
    let tracksEntered: Int
    let rank: Int
    let trackResults: [TrackResult]

    struct TrackResult: Identifiable {
        var id: String { trackId }
        let trackId: String
        let trackName: String
        let flag: String
        let rank: Int
        let points: Int
        let lapTimeMs: Int
    }

    var asDictionary: [String: Any] {
        [
            "playerId": playerId,
            "playerName": playerName,
            "totalPoints": totalPoints,
            "tracksEntered": tracksEntered,
            "rank": rank,
            "trackResults": trackResults.map { [
                "trackId": $0.trackId, "trackName": $0.trackName, "flag": $0.flag,
                "rank": $0.rank, "points": $0.points, "lapTimeMs": $0.lapTimeMs
            ] }
        ]
    }

    static func from(_ dict: [String: Any]) -> ChampionshipDetail? {
        guard let playerId = dict["playerId"] as? String,
              let playerName = dict["playerName"] as? String,
              let totalPoints = dict["totalPoints"] as? Int,
              let tracksEntered = dict["tracksEntered"] as? Int,
              let rank = dict["rank"] as? Int,
              let results = dict["trackResults"] as? [[String: Any]] else { return nil }
        let trackResults = results.compactMap { d -> TrackResult? in
            guard let tid = d["trackId"] as? String,
                  let tn = d["trackName"] as? String,
                  let f = d["flag"] as? String,
                  let r = d["rank"] as? Int,
                  let p = d["points"] as? Int,
                  let lt = d["lapTimeMs"] as? Int else { return nil }
            return TrackResult(trackId: tid, trackName: tn, flag: f, rank: r, points: p, lapTimeMs: lt)
        }
        return ChampionshipDetail(playerId: playerId, playerName: playerName, totalPoints: totalPoints, tracksEntered: tracksEntered, rank: rank, trackResults: trackResults)
    }
}

// Internal Codable struct for Supabase row decoding
private struct ChampionshipRow: Decodable {
    let player_id: String
    let player_name: String
    let total_points: Int
    let tracks_entered: Int
    let track_breakdown: [String: TrackBreakdownEntry]?

    struct TrackBreakdownEntry: Decodable {
        let rank: Int
        let points: Int
        let lap_time_ms: Int
    }
}
