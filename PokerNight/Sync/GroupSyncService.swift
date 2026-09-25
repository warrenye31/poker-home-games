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

    /// The newest write queued for each group. Every push, share, and remote
    /// delete waits for the one before it — see `serialized`.
    private var writeQueue: [UUID: Task<Void, Error>] = [:]
    /// Groups with a background push queued that hasn't started reading the
    /// group yet. A change made while one is waiting rides along with it.
    private var pendingPushes: Set<UUID> = []
    /// Groups with a Realtime-triggered pull already scheduled.
    private var pendingRealtimePulls: Set<UUID> = []

    private init() {}

    // MARK: - Admin: share + push

    /// Publishes (or re-publishes) a group to Supabase and returns its
    /// share join code. Safe to call again later to just re-sync.
    @discardableResult
    func shareGroup(_ group: GameGroup) async throws -> String {
        try await serialized(group.id) { try await self.pushSnapshot(for: group) }.value
        guard let code = group.joinCode else {
            throw SupabaseError.notConfigured
        }
        return code
    }

    /// Fire-and-forget re-push used at mutation call sites (add player, add
    /// buy-in, end session, etc). No-ops for groups that were never shared or
    /// for viewer-role local copies. Failures are logged, not surfaced —
    /// the admin's local data is always correct regardless of sync state.
    ///
    /// Pushes are queued, never run side by side. Two overlapping pushes used
    /// to race: an older one's orphan sweep, working from the rows it read
    /// before a newer push uploaded a fresh buy-in, would delete that row on
    /// the server until the next push put it back — and viewers watched it
    /// vanish in between. A short wait before each push also folds a burst
    /// of taps (three rebuys in a row) into one upload instead of three.
    func pushSnapshotIfShared(_ group: GameGroup) {
        guard group.isShared, group.role == .admin else { return }
        // One already waiting will read the group after this change, so it
        // covers it.
        guard pendingPushes.insert(group.id).inserted else { return }
        let groupId = group.id
        serialized(groupId) {
            try? await Task.sleep(for: .milliseconds(400))
            // From here on the push reads the group, so any later change
            // needs a push of its own, queued behind this one.
            self.pendingPushes.remove(groupId)
            // The group may have been deleted while this waited; pushing it
            // now would resurrect it on the server.
            guard group.modelContext != nil, !group.isDeleted, group.isShared else { return }
            do {
                try await self.pushSnapshot(for: group)
            } catch {
                #if DEBUG
                print("[Sync] background push failed: \(error)")
                #endif
            }
        }
    }

    /// Runs `operation` after every write already queued for this group has
    /// finished, successfully or not.
    @discardableResult
    private func serialized(
        _ groupId: UUID,
        _ operation: @escaping @MainActor () async throws -> Void
    ) -> Task<Void, Error> {
        let previous = writeQueue[groupId]
        let task = Task { @MainActor in
            _ = await previous?.result
            try await operation()
        }
        writeQueue[groupId] = task
        return task
    }

    private func pushSnapshot(for group: GameGroup) async throws {
        guard let client = auth.client else { throw SupabaseError.notConfigured }
        let userId = try await auth.ensureSignedIn()

        // Note the group row goes up without `admin_player_id` — it can't name a
        // player before the roster below exists. It's written at the end.
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

        // Best-effort, unlike everything above: a paid checkmark failing to
        // sync (say, a database that hasn't had 0004 run yet) must not take
        // sharing and the leaderboard down with it.
        do {
            try await pushPayments(for: group, client: client)
        } catch {
            #if DEBUG
            print("[Sync] settlement payment push failed: \(error)")
            #endif
        }

        // Now that the roster is on the server, the group may point at one of
        // its players. Deliberately last: sending this with the group's own
        // insert fails with `23503 groups_admin_player_id_fkey`, and sending it
        // before the orphan sweep could name a player the sweep then removes.
        if remoteGroup.adminPlayerId != group.adminPlayerID {
            try await client
                .from("groups")
                .update(RemoteGroupAdminPlayerUpdate(adminPlayerId: group.adminPlayerID))
                .eq("id", value: group.id.uuidString)
                .execute()
        }

        // Deleted locally mid-push: its properties are no longer safe to write.
        guard group.modelContext != nil, !group.isDeleted else { return }
        group.isShared = true
        group.joinCode = remoteGroup.joinCode
        // `adminPlayerID` is deliberately *not* read back here. On the admin
        // device the local value is the source of truth, and `remoteGroup` is
        // the pre-update read, so copying it would revert the pick just pushed.
        // (A viewer's `pullSnapshot` does read it back — there the server wins.)
        group.lastSyncedAt = .now
    }

    /// Paid checkmarks, so a viewer's Inbox knows what's been settled. A
    /// record whose player has since left the roster can't be sent — its
    /// foreign key would point at a row `pushSnapshot`'s sweep just removed.
    private func pushPayments(for group: GameGroup, client: SupabaseClient) async throws {
        let rosterIDs = Set(group.players.map(\.id))
        let allPayments = group.sessions.flatMap(\.settlementPayments)
        let paymentPayloads = allPayments.compactMap { payment -> RemoteSettlementPayment? in
            guard let session = payment.session,
                  let from = payment.fromPlayer, rosterIDs.contains(from.id),
                  let to = payment.toPlayer, rosterIDs.contains(to.id) else { return nil }
            return RemoteSettlementPayment(
                id: payment.id,
                groupId: group.id,
                sessionId: session.id,
                fromPlayerId: from.id,
                toPlayerId: to.id,
                amount: payment.amount,
                isPaid: payment.isPaid
            )
        }
        if !paymentPayloads.isEmpty {
            try await client.from("settlement_payments").upsert(paymentPayloads, onConflict: "id").execute()
        }
        try await deleteOrphans(
            table: "settlement_payments", groupId: group.id,
            keepIds: Set(paymentPayloads.map(\.id)), client: client
        )
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
            // `try?`: see `pushPayments`. `nil` leaves local checkmarks alone
            // rather than reading a failed fetch as "none are paid".
            let remotePayments: [RemoteSettlementPayment]? = try? await client
                .from("settlement_payments").select().eq("group_id", value: groupId.uuidString)
                .execute().value

            try self.applySnapshot(
                remoteGroup: remoteGroup, players: remotePlayers,
                sessions: remoteSessions, entries: remoteEntries,
                payments: remotePayments, context: context
            )
        }
    }

    /// The Supabase free tier pauses a project after ~7 days idle; the first
    /// request after that can be slow or time out while it wakes back up.
    /// Retry once after a short delay before surfacing the error to the UI.
    ///
    /// Only failures that a second try could fix. A `PostgrestError` is the
    /// server answering — a missing row, an RLS denial — and it will answer
    /// the same way three seconds later; a cancelled pull (the screen went
    /// away) shouldn't come back to life.
    private func withColdStartRetry<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let error where !(error is PostgrestError) && !(error is CancellationError) {
            try await Task.sleep(nanoseconds: 3_000_000_000)
            return try await operation()
        }
    }

    private func applySnapshot(
        remoteGroup: RemoteGroup,
        players: [RemotePlayer],
        sessions: [RemoteSession],
        entries: [RemoteSessionEntry],
        payments: [RemoteSettlementPayment]?,
        context: ModelContext
    ) throws {
        let group = try findOrCreateGroup(id: remoteGroup.id, context: context)
        group.name = remoteGroup.name
        group.createdDate = remoteGroup.createdDate
        group.role = .viewer
        group.isShared = true
        group.joinCode = remoteGroup.joinCode
        group.adminPlayerID = remoteGroup.adminPlayerId
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

        // Paid checkmarks. The server is the whole truth here — a viewer never
        // writes these — so anything local it doesn't list goes.
        if let payments {
            try applyPayments(payments, sessionsByID: sessionsByID, playersByID: playersByID, context: context)
        }

        try context.save()
    }

    private func applyPayments(
        _ payments: [RemoteSettlementPayment],
        sessionsByID: [UUID: Session],
        playersByID: [UUID: Player],
        context: ModelContext
    ) throws {
        let validPaymentIDs = Set(payments.map(\.id))
        for session in sessionsByID.values {
            for payment in session.settlementPayments where !validPaymentIDs.contains(payment.id) {
                context.delete(payment)
            }
        }
        for remotePayment in payments {
            guard let session = sessionsByID[remotePayment.sessionId],
                  let from = playersByID[remotePayment.fromPlayerId],
                  let to = playersByID[remotePayment.toPlayerId] else { continue }
            let payment = try findOrCreatePayment(
                id: remotePayment.id, session: session, from: from, to: to, context: context
            )
            payment.session = session
            payment.fromPlayer = from
            payment.toPlayer = to
            payment.amount = remotePayment.amount
            payment.isPaid = remotePayment.isPaid
        }
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

    private func findOrCreatePayment(
        id: UUID, session: Session, from: Player, to: Player, context: ModelContext
    ) throws -> SettlementPayment {
        var descriptor = FetchDescriptor<SettlementPayment>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first { return existing }
        let payment = SettlementPayment(session: session, fromPlayer: from, toPlayer: to, amount: 0, id: id)
        context.insert(payment)
        return payment
    }

    // MARK: - Admin: delete

    /// Deletes a shared group from the server so it stops existing for everyone
    /// who joined it. Without this an admin's "Delete" is local-only: the row
    /// survives, and every viewer keeps their copy indefinitely.
    ///
    /// Postgres cascades to players, sessions, session_entries, and
    /// group_members (`on delete cascade`), so this one statement clears the
    /// group's whole footprint. RLS allows it for the admin alone
    /// (`groups_delete`: `admin_id = auth.uid()`).
    ///
    /// Best-effort by design: the local delete proceeds regardless, matching
    /// `pushSnapshotIfShared`. A failure here leaves an orphaned remote row
    /// rather than blocking the user from deleting their own group.
    func deleteRemoteGroup(_ group: GameGroup) {
        guard group.role == .admin, group.isShared else { return }
        let groupId = group.id
        stopRealtimeSync(groupId: groupId)
        pendingPushes.remove(groupId)
        // Queued behind any push still in flight, so a push that was mid-way
        // when the group was deleted can't land after this and re-create it.
        serialized(groupId) {
            guard let client = self.auth.client else { return }
            do {
                try await self.auth.ensureSignedIn()
                try await client
                    .from("groups")
                    .delete()
                    .eq("id", value: groupId.uuidString)
                    .execute()
            } catch {
                #if DEBUG
                print("[Sync] remote group delete failed: \(error)")
                #endif
            }
        }
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
            do {
                try await client
                    .from("group_members")
                    .delete()
                    .eq("group_id", value: groupId.uuidString)
                    .eq("user_id", value: userId.uuidString)
                    .execute()
            } catch {
                // Best-effort, like the other fire-and-forget syncs: the local
                // copy goes regardless. Worst case a stale membership row
                // lingers, which grants no access on its own.
                #if DEBUG
                print("[Sync] leave group failed: \(error)")
                #endif
            }
        }
    }

    // MARK: - Viewer: Realtime

    /// Starts a best-effort live subscription for a group; on any change,
    /// re-pulls the full snapshot. If Realtime is unavailable for any reason,
    /// this silently no-ops — callers should still pull on appear/refresh.
    ///
    /// Watches every synced table, not just the money: a renamed player, a
    /// session moved to another date, or a new paid checkmark would otherwise
    /// only reach a viewer when they pulled to refresh.
    func startRealtimeSync(groupId: UUID, context: ModelContext) {
        guard let client = auth.client, realtimeTasks[groupId] == nil else { return }
        let task = Task {
            do {
                let channel = client.channel("group-\(groupId.uuidString)")
                let byGroup = ["players", "sessions", "session_entries", "settlement_payments"].map { table in
                    channel.postgresChange(
                        AnyAction.self,
                        schema: "public",
                        table: table,
                        filter: .eq("group_id", value: groupId.uuidString)
                    )
                }
                let groupRow = channel.postgresChange(
                    AnyAction.self,
                    schema: "public",
                    table: "groups",
                    filter: .eq("id", value: groupId.uuidString)
                )
                // `subscribeWithError`, not the deprecated `subscribe()`: the
                // latter doesn't throw, so the catch below was unreachable and a
                // Realtime failure was swallowed in silence — viewers would sit
                // on stale data with nothing logged and no fallback triggered.
                try await channel.subscribeWithError()
                await withTaskGroup(of: Void.self) { tasks in
                    for changes in byGroup + [groupRow] {
                        tasks.addTask { @MainActor in
                            for await _ in changes {
                                self.scheduleRealtimePull(groupId: groupId, context: context)
                            }
                        }
                    }
                }
            } catch {
                #if DEBUG
                print("[Sync] realtime subscription unavailable, relying on manual refresh: \(error)")
                #endif
            }
        }
        realtimeTasks[groupId] = task
    }

    /// One admin push upserts every row in the group, which arrives here as a
    /// change event per row. Pulling the whole snapshot once per event would be
    /// dozens of identical pulls, so a burst collapses into one.
    private func scheduleRealtimePull(groupId: UUID, context: ModelContext) {
        guard pendingRealtimePulls.insert(groupId).inserted else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            pendingRealtimePulls.remove(groupId)
            guard realtimeTasks[groupId] != nil else { return }
            try? await pullSnapshot(groupId: groupId, context: context)
        }
    }

    func stopRealtimeSync(groupId: UUID) {
        realtimeTasks[groupId]?.cancel()
        realtimeTasks[groupId] = nil
        guard let client = auth.client else { return }
        Task { await client.channel("group-\(groupId.uuidString)").unsubscribe() }
    }
}
