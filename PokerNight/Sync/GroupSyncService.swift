import Foundation
import SwiftData
import Supabase

/// Drives all group sharing sync: admin devices push their local SwiftData
/// state up to Supabase; viewer devices pull it back down and subscribe to
/// Realtime for live updates. Local SwiftData stays the source of truth for
/// the admin — the server is a read cache for viewers.
///
/// NOTE on the Realtime piece (`startRealtimeSync`): this uses the
/// supabase-swift v2 `client.channel(...).postgresChange(...)` API. That API
/// has shifted across library minor versions, so if the resolved package
/// version doesn't match, this is the single most likely spot to need a small
/// signature tweak. Everything else (push/pull/join/leave) doesn't depend on
/// Realtime and works standalone — a viewer still gets fresh data every time
/// their screen appears via `pullSnapshot`, even if the live subscription
/// fails to compile-fix on the first try.
@MainActor
final class GroupSyncService {
    static let shared = GroupSyncService()

    private let auth = SupabaseService.shared
    private var realtimeTasks: [UUID: Task<Void, Never>] = [:]

    private init() {}

    // MARK: - Admin: share + push

    /// Publishes (or re-publishes) a group to Supabase and returns its
    /// share join code. Safe to call again later to just re-sync.
    @discardableResult
    func shareGroup(_ group: GameGroup) async throws -> String {
        try await pushSnapshot(for: group)
        guard let code = group.joinCode else {
            throw SupabaseError.notConfigured
        }
        return code
    }

    /// Fire-and-forget re-push used at mutation call sites (add player, add
    /// buy-in, end session, etc). No-ops for groups that were never shared or
    /// for viewer-role local copies. Failures are logged, not surfaced —
    /// the admin's local data is always correct regardless of sync state.
    func pushSnapshotIfShared(_ group: GameGroup) {
        guard group.isShared, group.role == .admin else { return }
        Task {
            do {
                try await pushSnapshot(for: group)
            } catch {
                #if DEBUG
                print("[Sync] background push failed: \(error)")
                #endif
            }
        }
    }

    private func pushSnapshot(for group: GameGroup) async throws {
        guard let client = auth.client else { throw SupabaseError.notConfigured }
        let userId = try await auth.ensureSignedIn()

        let groupPayload = RemoteGroupUpsert(
            id: group.id,
            name: group.name,
            createdDate: group.createdDate,
            adminId: userId
        )
        let remoteGroup: RemoteGroup = try await client
            .from("groups")
            .upsert(groupPayload, onConflict: "id")
            .select()
            .single()
            .execute()
            .value

        let playerPayloads = group.players.map {
            RemotePlayer(id: $0.id, groupId: group.id, name: $0.name)
        }
        if !playerPayloads.isEmpty {
            try await client.from("players").upsert(playerPayloads, onConflict: "id").execute()
        }
        try await deleteOrphans(
            table: "players", groupId: group.id,
            keepIds: Set(group.players.map(\.id)), client: client
        )

        let sessionPayloads = group.sessions.map { session in
            RemoteSession(
                id: session.id,
                groupId: group.id,
                date: session.date,
                location: session.location,
                usesBank: session.usesBank,
                bankPlayerId: session.bankPlayer?.id,
                smallBlind: session.smallBlind,
                bigBlind: session.bigBlind,
                standardBuyIn: session.standardBuyIn,
                status: session.status.rawValue
            )
        }
        if !sessionPayloads.isEmpty {
            try await client.from("sessions").upsert(sessionPayloads, onConflict: "id").execute()
        }
        try await deleteOrphans(
            table: "sessions", groupId: group.id,
            keepIds: Set(group.sessions.map(\.id)), client: client
        )

        let allEntries = group.sessions.flatMap(\.entries)
        let entryPayloads = allEntries.compactMap { entry -> RemoteSessionEntry? in
            guard let session = entry.session, let player = entry.player else { return nil }
            return RemoteSessionEntry(
                id: entry.id,
                groupId: group.id,
                sessionId: session.id,
                playerId: player.id,
                totalBuyIn: entry.totalBuyIn,
                cashOut: entry.cashOut
            )
        }
        if !entryPayloads.isEmpty {
            try await client.from("session_entries").upsert(entryPayloads, onConflict: "id").execute()
        }
        try await deleteOrphans(
            table: "session_entries", groupId: group.id,
            keepIds: Set(allEntries.map(\.id)), client: client
        )

        group.isShared = true
        group.joinCode = remoteGroup.joinCode
        group.lastSyncedAt = .now
    }

    /// Deletes rows for `groupId` that exist remotely but not in `keepIds` —
    /// e.g. a player or session the admin deleted locally since the last push.
    private func deleteOrphans(table: String, groupId: UUID, keepIds: Set<UUID>, client: SupabaseClient) async throws {
        struct RowID: Decodable { var id: UUID }
        let rows: [RowID] = try await client
            .from(table)
            .select("id")
            .eq("group_id", value: groupId.uuidString)
            .execute()
            .value
        let staleIds = rows.map(\.id).filter { !keepIds.contains($0) }
        guard !staleIds.isEmpty else { return }
        try await client
            .from(table)
            .delete()
            .in("id", values: staleIds.map(\.uuidString))
            .execute()
    }

    // MARK: - Viewer: join + pull

    /// Joins a group by its share code and pulls its current snapshot into a
    /// local, read-only mirror `GameGroup`. Returns that local group.
    func joinGroup(code: String, context: ModelContext) async throws -> GameGroup {
        guard let client = auth.client else { throw SupabaseError.notConfigured }
        try await auth.ensureSignedIn()

        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let remoteGroup: RemoteGroup = try await client
            .rpc("join_group_with_code", params: JoinGroupParams(pCode: trimmedCode))
            .execute()
            .value

        try await pullSnapshot(groupId: remoteGroup.id, context: context)

        var descriptor = FetchDescriptor<GameGroup>(
            predicate: #Predicate { $0.id == remoteGroup.id }
        )
        descriptor.fetchLimit = 1
        guard let group = try context.fetch(descriptor).first else {
            throw SupabaseError.notConfigured
        }
        return group
    }

    /// Re-pulls a viewer group's current state from Supabase. Used for
    /// pull-to-refresh, on-appear refresh, and as the Realtime change handler.
    func pullSnapshot(groupId: UUID, context: ModelContext) async throws {
        guard let client = auth.client else { throw SupabaseError.notConfigured }
        try await withColdStartRetry {
            let remoteGroup: RemoteGroup = try await client
                .from("groups").select().eq("id", value: groupId.uuidString).single()
                .execute().value
            let remotePlayers: [RemotePlayer] = try await client
                .from("players").select().eq("group_id", value: groupId.uuidString)
                .execute().value
            let remoteSessions: [RemoteSession] = try await client
                .from("sessions").select().eq("group_id", value: groupId.uuidString)
                .execute().value
            let remoteEntries: [RemoteSessionEntry] = try await client
                .from("session_entries").select().eq("group_id", value: groupId.uuidString)
                .execute().value

            try self.applySnapshot(
                remoteGroup: remoteGroup, players: remotePlayers,
                sessions: remoteSessions, entries: remoteEntries, context: context
            )
        }
    }

    /// The Supabase free tier pauses a project after ~7 days idle; the first
    /// request after that can be slow or time out while it wakes back up.
    /// Retry once after a short delay before surfacing the error to the UI.
    private func withColdStartRetry<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch {
            try await Task.sleep(nanoseconds: 3_000_000_000)
            return try await operation()
        }
    }

    private func applySnapshot(
        remoteGroup: RemoteGroup,
        players: [RemotePlayer],
        sessions: [RemoteSession],
        entries: [RemoteSessionEntry],
        context: ModelContext
    ) throws {
        let group = try findOrCreateGroup(id: remoteGroup.id, context: context)
        group.name = remoteGroup.name
        group.createdDate = remoteGroup.createdDate
        group.role = .viewer
        group.isShared = true
        group.joinCode = remoteGroup.joinCode
        group.lastSyncedAt = .now

        var playersByID: [UUID: Player] = [:]
        for remotePlayer in players {
            let player = try findOrCreatePlayer(id: remotePlayer.id, context: context)
            player.name = remotePlayer.name
            player.group = group
            playersByID[remotePlayer.id] = player
        }
        for local in group.players where playersByID[local.id] == nil {
            context.delete(local)
        }

        var sessionsByID: [UUID: Session] = [:]
        for remoteSession in sessions {
            let session = try findOrCreateSession(id: remoteSession.id, context: context)
            session.date = remoteSession.date
            session.location = remoteSession.location
            session.usesBank = remoteSession.usesBank
            session.bankPlayer = remoteSession.bankPlayerId.flatMap { playersByID[$0] }
            session.smallBlind = remoteSession.smallBlind
            session.bigBlind = remoteSession.bigBlind
            session.standardBuyIn = remoteSession.standardBuyIn
            session.status = SessionStatus(rawValue: remoteSession.status) ?? .active
            session.group = group
            sessionsByID[remoteSession.id] = session
        }
        for local in group.sessions where sessionsByID[local.id] == nil {
            context.delete(local)
        }

        let validEntryIDs = Set(entries.map(\.id))
        for session in sessionsByID.values {
            for entry in session.entries where !validEntryIDs.contains(entry.id) {
                context.delete(entry)
            }
        }
        for remoteEntry in entries {
            guard let session = sessionsByID[remoteEntry.sessionId],
                  let player = playersByID[remoteEntry.playerId] else { continue }
            let entry = try findOrCreateEntry(id: remoteEntry.id, player: player, context: context)
            entry.session = session
            entry.player = player
            entry.cashOut = remoteEntry.cashOut
            // Individual buy-ins aren't mirrored server-side (only the total),
            // so represent the total as a single synthetic BuyIn — this keeps
            // `SessionEntry.totalBuyIn` correct without needing buy-in history.
            applyTotalBuyIn(remoteEntry.totalBuyIn, to: entry, context: context)
        }

        try context.save()
    }

    private func applyTotalBuyIn(_ amount: Decimal, to entry: SessionEntry, context: ModelContext) {
        if entry.buyIns.count == 1 {
            entry.buyIns[0].amount = amount
        } else {
            for buyIn in entry.buyIns { context.delete(buyIn) }
            let buyIn = BuyIn(amount: amount)
            context.insert(buyIn)
            entry.buyIns = [buyIn]
        }
    }

    private func findOrCreateGroup(id: UUID, context: ModelContext) throws -> GameGroup {
        var descriptor = FetchDescriptor<GameGroup>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first { return existing }
        let group = GameGroup(name: "", id: id, role: .viewer)
        context.insert(group)
        return group
    }

    private func findOrCreatePlayer(id: UUID, context: ModelContext) throws -> Player {
        var descriptor = FetchDescriptor<Player>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first { return existing }
        let player = Player(name: "", id: id)
        context.insert(player)
        return player
    }

    private func findOrCreateSession(id: UUID, context: ModelContext) throws -> Session {
        var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first { return existing }
        let session = Session(id: id)
        context.insert(session)
        return session
    }

    private func findOrCreateEntry(id: UUID, player: Player, context: ModelContext) throws -> SessionEntry {
        var descriptor = FetchDescriptor<SessionEntry>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first { return existing }
        let entry = SessionEntry(player: player, id: id)
        context.insert(entry)
        return entry
    }

    // MARK: - Viewer: leave

    /// Removes this device's membership and stops watching a group it joined.
    /// Does not touch the admin's data — only unregisters this viewer.
    func leaveGroup(_ group: GameGroup) {
        guard group.role == .viewer, group.isShared else { return }
        let groupId = group.id
        stopRealtimeSync(groupId: groupId)
        Task {
            guard let client = auth.client, let userId = auth.currentUserID else { return }
            try? await client
                .from("group_members")
                .delete()
                .eq("group_id", value: groupId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()
        }
    }

    // MARK: - Viewer: Realtime

    /// Starts a best-effort live subscription for a group; on any change,
    /// re-pulls the full snapshot. If Realtime is unavailable for any reason,
    /// this silently no-ops — callers should still pull on appear/refresh.
    func startRealtimeSync(groupId: UUID, context: ModelContext) {
        guard let client = auth.client, realtimeTasks[groupId] == nil else { return }
        let task = Task {
            do {
                let channel = client.channel("group-\(groupId.uuidString)")
                let changes = channel.postgresChange(
                    AnyAction.self,
                    schema: "public",
                    table: "session_entries",
                    filter: "group_id=eq.\(groupId.uuidString)"
                )
                try await channel.subscribe()
                for await _ in changes {
                    try? await self.pullSnapshot(groupId: groupId, context: context)
                }
            } catch {
                #if DEBUG
                print("[Sync] realtime subscription unavailable, relying on manual refresh: \(error)")
                #endif
            }
        }
        realtimeTasks[groupId] = task
    }

    func stopRealtimeSync(groupId: UUID) {
        realtimeTasks[groupId]?.cancel()
        realtimeTasks[groupId] = nil
        guard let client = auth.client else { return }
        Task { await client.channel("group-\(groupId.uuidString)").unsubscribe() }
    }
}
