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

    /// Check if own data exists in Supabase; if not, backfill from GC personal bests.
    /// Called once after GC auth completes.
    func reconcileFromGameCenter() async {
        let player = GKLocalPlayer.local
        guard player.isAuthenticated else { return }

        // Check if we already have data in Supabase
        let existing = try? await loadPlayerStanding(playerId: player.gamePlayerID)
        if existing != nil {
            print("[Supabase] reconcile: own data already exists, skipping")
            return
        }

        // Backfill own personal bests from GC
        let bestTimes = await GameCenterManager.shared.loadMyBestTimes()
        guard !bestTimes.isEmpty else {
            print("[Supabase] reconcile: no GC best times found")
            return
        }

        print("[Supabase] reconcile: backfilling \(bestTimes.count) own tracks")
        for (trackId, lapTime) in bestTimes {
            try? await submitLapTime(
                playerId: player.gamePlayerID,
                playerName: player.displayName,
                trackId: trackId,
                lapTimeMs: Int(lapTime * 1000)
            )
        }
        print("[Supabase] reconcile: backfill complete")
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
