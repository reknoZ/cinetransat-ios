//
//  WatchListStatsStore.swift
//  CinéTransat
//
//  Watch list popularity = `watchlistDevices/{screeningId}.devices`.count.
//  On app open, sync reconciles local storage with Firestore (including reinstall restore).
//

import Combine
import Foundation
import Network
import OSLog

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class WatchListStatsStore: ObservableObject {
    private static let logger = Logger(subsystem: "com.heewhack.CineTransat", category: "WatchListStats")
    private static let pendingDeltasKey = "watchlistStatsPendingDeltas"

    /// Screening day key (`yyyyMMdd`) → number of distinct installs interested.
    @Published private(set) var countByScreeningID: [String: Int] = [:]

    #if canImport(FirebaseFirestore)
    private lazy var db = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]
    private var devicesCountByScreeningID: [String: Int] = [:]
    private var pathMonitor: NWPathMonitor?
    #endif

    private var activeSyncTask: Task<Set<String>, Never>?

    init() {
        #if canImport(FirebaseFirestore)
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in
                await self?.onFirestoreServerReachable()
            }
        }
        monitor.start(queue: DispatchQueue(label: "WatchListStats.network"))
        pathMonitor = monitor
        #endif
    }

    func count(screeningId: String) -> Int? {
        countByScreeningID[screeningId]
    }

    /// Immediate UI bump while the Firestore write is in flight.
    func applyOptimisticDelta(screeningId: String, delta: Int) {
        guard delta == 1 || delta == -1 else { return }
        let next = max(0, (countByScreeningID[screeningId] ?? 0) + delta)
        setCount(next, for: screeningId)
    }

    func startObserving(screeningId: String) {
        guard !AppStoreScreenshotConfiguration.isActive else { return }
        #if canImport(FirebaseFirestore)
        guard listeners[screeningId] == nil else { return }
        let ref = db.document(FirestorePaths.watchlistDevices(screeningId: screeningId))
        listeners[screeningId] = ref.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    Self.logger.error("Devices listener (\(screeningId)): \(error.localizedDescription)")
                    return
                }
                self.devicesCountByScreeningID[screeningId] = Self.deviceCount(from: snapshot?.data())
                self.publishCount(for: screeningId)
            }
        }
        #endif
    }

    func stopObserving(screeningId: String) {
        #if canImport(FirebaseFirestore)
        listeners[screeningId]?.remove()
        listeners[screeningId] = nil
        devicesCountByScreeningID[screeningId] = nil
        #endif
    }

    func syncObservations(screeningIds: Set<String>) {
        #if canImport(FirebaseFirestore)
        let stale = Set(listeners.keys).subtracting(screeningIds)
        for id in stale {
            stopObserving(screeningId: id)
        }
        #endif
        for id in screeningIds {
            startObserving(screeningId: id)
        }
    }

    func stopAllObservations() {
        #if canImport(FirebaseFirestore)
        for id in Array(listeners.keys) {
            stopObserving(screeningId: id)
        }
        #endif
    }

    func onFirestoreServerReachable() async {
        guard !AppStoreScreenshotConfiguration.isActive else { return }
        #if canImport(FirebaseFirestore)
        try? await db.enableNetwork()
        await flushPendingDeltas()
        #endif
    }

    @discardableResult
    func recordDelta(screeningId: String, delta: Int) async -> Bool {
        guard delta == 1 || delta == -1 else { return false }
        guard !AppStoreScreenshotConfiguration.isActive else { return false }
        let success = await attemptServerDelta(screeningId: screeningId, delta: delta)
        if !success {
            enqueuePendingDelta(screeningId: screeningId, delta: delta)
        }
        return success
    }

    /// Reconcile local watch list with Firestore for this install.
    /// Returns the watch list IDs that should be stored locally (unchanged, or restored on reinstall).
    func syncWithLocalWatchList(_ localIDs: Set<String>) async -> Set<String> {
        if let activeSyncTask {
            return await activeSyncTask.value
        }

        let task = Task { @MainActor in
            await self.performSyncWithLocalWatchList(localIDs)
        }
        activeSyncTask = task
        let result = await task.value
        activeSyncTask = nil
        return result
    }

    func flushPendingDeltas() async {
        guard !AppStoreScreenshotConfiguration.isActive else { return }
        #if canImport(FirebaseFirestore)
        try? await db.enableNetwork()

        var pending = loadPendingDeltas()
        guard !pending.isEmpty else { return }

        Self.logger.info("Flushing \(pending.count) pending watchlist write(s)")
        var remaining: [PendingDelta] = []
        for entry in pending {
            let success = await attemptServerDelta(screeningId: entry.screeningId, delta: entry.delta)
            if !success {
                remaining.append(entry)
            }
        }
        savePendingDeltas(remaining)
        #endif
    }

    /// How many *other* people (excluding the current user when in the watch list).
    static func othersCount(total: Int, inWatchList: Bool) -> Int {
        guard total > 0 else { return 0 }
        return inWatchList ? max(0, total - 1) : total
    }

    private func performSyncWithLocalWatchList(_ localIDs: Set<String>) async -> Set<String> {
        guard !AppStoreScreenshotConfiguration.isActive else { return localIDs }
        #if canImport(FirebaseFirestore)
        try? await db.enableNetwork()

        let remoteIDs = await fetchContributedScreeningIDs()
        Self.logger.info(
            "syncWithLocalWatchList local=\(localIDs.count) remote=\(remoteIDs.count)"
        )

        let reconciled: Set<String>
        if localIDs.isEmpty, !remoteIDs.isEmpty {
            Self.logger.info("Reinstall restore — \(remoteIDs.count) screening(s) from Firestore")
            reconciled = remoteIDs
        } else {
            for id in localIDs.subtracting(remoteIDs) {
                await registerDevice(screeningId: id)
            }
            for id in remoteIDs.subtracting(localIDs) {
                await unregisterDevice(screeningId: id)
            }
            reconciled = localIDs
        }

        await flushPendingDeltas()
        return reconciled
        #else
        return localIDs
        #endif
    }

    #if canImport(FirebaseFirestore)
    private func registerDevice(screeningId: String) async {
        _ = await attemptServerDelta(screeningId: screeningId, delta: 1)
    }

    private func unregisterDevice(screeningId: String) async {
        _ = await attemptServerDelta(screeningId: screeningId, delta: -1)
    }

    private func attemptServerDelta(screeningId: String, delta: Int) async -> Bool {
        let deviceId = AnonymousDeviceIdentity.deviceID
        let ref = db.document(FirestorePaths.watchlistDevices(screeningId: screeningId))

        do {
            if delta == 1 {
                let snap = try await ref.getDocument()
                if Self.devices(from: snap.data()).contains(deviceId) {
                    removePendingDelta(screeningId: screeningId, delta: delta)
                    return true
                }
                try await ref.setData(
                    ["devices": FieldValue.arrayUnion([deviceId])],
                    merge: true
                )
            } else {
                let snap = try await ref.getDocument()
                guard Self.devices(from: snap.data()).contains(deviceId) else {
                    removePendingDelta(screeningId: screeningId, delta: delta)
                    return true
                }
                try await ref.updateData(["devices": FieldValue.arrayRemove([deviceId])])
            }

            removePendingDelta(screeningId: screeningId, delta: delta)
            Self.logger.info(
                "Devices \(delta == 1 ? "+" : "−")1 for \(screeningId) (…\(deviceId.suffix(6)))"
            )
            return true
        } catch {
            Self.logger.error("Write failed \(screeningId) Δ\(delta): \(error.localizedDescription)")
            return false
        }
    }

    private func fetchContributedScreeningIDs() async -> Set<String> {
        let deviceId = AnonymousDeviceIdentity.deviceID
        do {
            let snapshot = try await db.collection(FirestorePaths.watchlistDevicesCollection)
                .whereField("devices", arrayContains: deviceId)
                .getDocuments()
            return Set(snapshot.documents.map(\.documentID))
        } catch {
            Self.logger.warning("Contributed IDs query failed: \(error.localizedDescription)")
            return []
        }
    }

    private func publishCount(for screeningId: String) {
        let count = devicesCountByScreeningID[screeningId] ?? 0
        setCount(count, for: screeningId)
    }
    #endif

    private struct PendingDelta: Codable, Equatable {
        let screeningId: String
        let delta: Int
    }

    private func enqueuePendingDelta(screeningId: String, delta: Int) {
        var pending = loadPendingDeltas()
        pending.removeAll { $0.screeningId == screeningId && $0.delta == -delta }
        pending.append(PendingDelta(screeningId: screeningId, delta: delta))
        savePendingDeltas(pending)
        Self.logger.info("Queued pending Δ\(delta) for \(screeningId) (count=\(pending.count))")
    }

    private func removePendingDelta(screeningId: String, delta: Int) {
        var pending = loadPendingDeltas()
        pending.removeAll { $0.screeningId == screeningId && $0.delta == delta }
        savePendingDeltas(pending)
    }

    private func loadPendingDeltas() -> [PendingDelta] {
        guard let data = UserDefaults.standard.data(forKey: Self.pendingDeltasKey) else { return [] }
        return (try? JSONDecoder().decode([PendingDelta].self, from: data)) ?? []
    }

    private func savePendingDeltas(_ deltas: [PendingDelta]) {
        if deltas.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.pendingDeltasKey)
            return
        }
        if let data = try? JSONEncoder().encode(deltas) {
            UserDefaults.standard.set(data, forKey: Self.pendingDeltasKey)
        }
    }

    private static func devices(from data: [String: Any]?) -> [String] {
        data?["devices"] as? [String] ?? []
    }

    private static func deviceCount(from data: [String: Any]?) -> Int {
        devices(from: data).count
    }

    private func setCount(_ count: Int, for screeningId: String) {
        var updated = countByScreeningID
        if updated[screeningId] == count { return }
        updated[screeningId] = count
        countByScreeningID = updated
    }
}
