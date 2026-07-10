//
//  WatchListStatsStore.swift
//  CinéTransat
//
//  Transition: displayed count = legacy `watchlistStats.count` + `watchlistDevices.devices`.count
//  until the legacy collection is retired. New writes go only to `watchlistDevices`.
//

import Combine
import Foundation
import OSLog
import Security

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class WatchListStatsStore: ObservableObject {
    private static let logger = Logger(subsystem: "com.heewhack.CineTransat", category: "WatchListStats")

    /// Combined headcount shown in the UI (legacy + devices during transition).
    @Published private(set) var countByScreeningID: [String: Int] = [:]

    #if canImport(FirebaseFirestore)
    private lazy var db = Firestore.firestore()
    private var listeners: [String: ScreeningListeners] = [:]
    private var legacyFlatCountByScreeningID: [String: Int] = [:]
    private var legacyFlatDocumentExists: [String: Bool] = [:]
    private var legacyNestedCountByScreeningID: [String: Int] = [:]
    private var legacyNestedDocumentExists: [String: Bool] = [:]
    private var devicesCountByScreeningID: [String: Int] = [:]
    #endif

    private var activeSyncTask: Task<Void, Never>?
    private var cachedContributedIDs: Set<String>?
    private var cachedContributedDeviceID: String?

    private static let devicesSchemaV2MigrationKeychainAccount = "watchlistDevicesSchemaV2Migrated"

    #if canImport(FirebaseFirestore)
    private struct ScreeningListeners {
        var legacyFlat: ListenerRegistration?
        var legacyNested: ListenerRegistration?
        var devices: ListenerRegistration?
    }
    #endif

    func count(screeningId: String) -> Int? {
        countByScreeningID[screeningId]
    }

    func startObserving(screeningId: String) {
        guard !AppStoreScreenshotConfiguration.isActive else { return }
        #if canImport(FirebaseFirestore)
        var bucket = listeners[screeningId] ?? ScreeningListeners()

        if bucket.devices == nil {
            let ref = db.document(FirestorePaths.watchlistDevices(screeningId: screeningId))
            bucket.devices = ref.addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        Self.logger.error("Devices listener (\(screeningId)): \(error.localizedDescription)")
                        return
                    }
                    self.devicesCountByScreeningID[screeningId] = Self.deviceCount(from: snapshot?.data())
                    self.publishCombinedCount(for: screeningId)
                }
            }
        }

        if bucket.legacyFlat == nil {
            let ref = db.document(FirestorePaths.watchlistStatsLegacy(screeningId: screeningId))
            bucket.legacyFlat = ref.addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        Self.logger.error("Legacy flat listener (\(screeningId)): \(error.localizedDescription)")
                        return
                    }
                    self.legacyFlatDocumentExists[screeningId] = snapshot?.exists == true
                    self.legacyFlatCountByScreeningID[screeningId] = Self.legacyCount(from: snapshot?.data())
                    self.publishCombinedCount(for: screeningId)
                }
            }
        }

        if bucket.legacyNested == nil {
            let seasonYear = Self.seasonYear(for: screeningId)
            let ref = db.document(
                FirestorePaths.watchlistStatsLegacyNested(seasonYear: seasonYear, screeningId: screeningId)
            )
            bucket.legacyNested = ref.addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        Self.logger.error("Legacy nested listener (\(screeningId)): \(error.localizedDescription)")
                        return
                    }
                    self.legacyNestedDocumentExists[screeningId] = snapshot?.exists == true
                    self.legacyNestedCountByScreeningID[screeningId] = Self.legacyCount(from: snapshot?.data())
                    self.publishCombinedCount(for: screeningId)
                }
            }
        }

        listeners[screeningId] = bucket
        #endif
    }

    func stopObserving(screeningId: String) {
        #if canImport(FirebaseFirestore)
        listeners[screeningId]?.legacyFlat?.remove()
        listeners[screeningId]?.legacyNested?.remove()
        listeners[screeningId]?.devices?.remove()
        listeners[screeningId] = nil
        legacyFlatCountByScreeningID[screeningId] = nil
        legacyFlatDocumentExists[screeningId] = nil
        legacyNestedCountByScreeningID[screeningId] = nil
        legacyNestedDocumentExists[screeningId] = nil
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

    @discardableResult
    func recordDelta(screeningId: String, seasonYear: Int, delta: Int) async -> Bool {
        guard delta == 1 || delta == -1 else { return false }
        guard !AppStoreScreenshotConfiguration.isActive else { return false }
        #if canImport(FirebaseFirestore)
        let deviceId = AnonymousDeviceIdentity.deviceID
        let ref = db.document(FirestorePaths.watchlistDevices(screeningId: screeningId))

        do {
            if delta == 1 {
                let snap = try await ref.getDocument()
                if Self.devices(from: snap.data()).contains(deviceId) {
                    return true
                }
                try await ref.setData(
                    ["devices": FieldValue.arrayUnion([deviceId])],
                    merge: true
                )
            } else {
                let snap = try await ref.getDocument()
                guard Self.devices(from: snap.data()).contains(deviceId) else { return true }
                try await ref.updateData(["devices": FieldValue.arrayRemove([deviceId])])
            }

            invalidateContributionCache()
            Self.logger.info(
                "Devices \(delta == 1 ? "+" : "−")1 for \(screeningId) (…\(deviceId.suffix(6)))"
            )
            return true
        } catch {
            Self.logger.error("Write failed \(screeningId) Δ\(delta): \(error.localizedDescription)")
            return false
        }
        #else
        return false
        #endif
    }

    func syncWithLocalWatchList(_ screeningIDs: Set<String>, seasonYear: Int) async {
        if let activeSyncTask {
            await activeSyncTask.value
            return
        }

        let task = Task { @MainActor in
            await self.performSyncWithLocalWatchList(screeningIDs, seasonYear: seasonYear)
        }
        activeSyncTask = task
        await task.value
        activeSyncTask = nil
    }

    private func performSyncWithLocalWatchList(_ screeningIDs: Set<String>, seasonYear: Int) async {
        guard !AppStoreScreenshotConfiguration.isActive else { return }
        await migrateToDevicesSchemaV2IfNeeded(localWatchlistIDs: screeningIDs, seasonYear: seasonYear)

        var contributed = await fetchContributedScreeningIDs()

        for id in contributed where !screeningIDs.contains(id) {
            _ = await recordDelta(screeningId: id, seasonYear: seasonYear, delta: -1)
            contributed.remove(id)
        }

        for id in screeningIDs where !contributed.contains(id) {
            if await recordDelta(screeningId: id, seasonYear: seasonYear, delta: 1) {
                contributed.insert(id)
            }
        }
    }

    private func migrateToDevicesSchemaV2IfNeeded(
        localWatchlistIDs: Set<String>,
        seasonYear: Int
    ) async {
        if Self.hasCompletedDevicesSchemaV2Migration { return }
        // Builds before Keychain flag used UserDefaults — treat as already migrated.
        if UserDefaults.standard.bool(forKey: "watchlistDevicesSchemaV2Migrated") {
            Self.markDevicesSchemaV2MigrationComplete()
            return
        }

        let legacyDefaultsIDs = legacyUserDefaultsContributedIDs(seasonYear: seasonYear)
        clearLegacyUserDefaultsContributions(seasonYear: seasonYear)

        let idsToRegister = localWatchlistIDs.union(legacyDefaultsIDs)
        for id in idsToRegister {
            _ = await recordDelta(screeningId: id, seasonYear: seasonYear, delta: 1)
        }
        for id in legacyDefaultsIDs {
            await relinquishLegacyContribution(screeningId: id, seasonYear: seasonYear)
        }

        Self.markDevicesSchemaV2MigrationComplete()
        invalidateContributionCache()
        Self.logger.info(
            "watchlistDevices v2 migration — registered \(idsToRegister.count) screening(s), relinquished legacy for \(legacyDefaultsIDs.count)"
        )
    }

    // MARK: - Legacy transition

    #if canImport(FirebaseFirestore)
    /// Drop this install's old +1 from legacy `watchlistStats` after registering in `watchlistDevices`.
    private func relinquishLegacyContribution(screeningId: String, seasonYear: Int) async {
        let flatRef = db.document(FirestorePaths.watchlistStatsLegacy(screeningId: screeningId))
        let nestedRef = db.document(
            FirestorePaths.watchlistStatsLegacyNested(seasonYear: seasonYear, screeningId: screeningId)
        )

        for ref in [flatRef, nestedRef] {
            do {
                let changed = try await db.runTransaction { transaction, errorPointer -> Any? in
                    let snapshot: DocumentSnapshot
                    do {
                        snapshot = try transaction.getDocument(ref)
                    } catch {
                        errorPointer?.pointee = error as NSError
                        return nil
                    }
                    guard snapshot.exists else { return false }
                    let current = Self.legacyCount(from: snapshot.data())
                    guard current > 0 else { return false }
                    transaction.setData(["count": current - 1], forDocument: ref, merge: true)
                    return true
                }
                if changed as? Bool == true {
                    Self.logger.debug("Legacy relinquish −1 for \(screeningId) at \(ref.path)")
                    return
                }
            } catch {
                Self.logger.debug("Legacy relinquish skipped for \(screeningId): \(error.localizedDescription)")
            }
        }
    }

    private func publishCombinedCount(for screeningId: String) {
        let legacy = effectiveLegacyCount(for: screeningId)
        let devices = devicesCountByScreeningID[screeningId] ?? 0
        setCount(legacy + devices, for: screeningId)
    }

    private func effectiveLegacyCount(for screeningId: String) -> Int {
        if legacyFlatDocumentExists[screeningId] == true {
            return legacyFlatCountByScreeningID[screeningId] ?? 0
        }
        if legacyNestedDocumentExists[screeningId] == true {
            return legacyNestedCountByScreeningID[screeningId] ?? 0
        }
        return 0
    }

    private func fetchContributedScreeningIDs() async -> Set<String> {
        let deviceId = AnonymousDeviceIdentity.deviceID
        if cachedContributedDeviceID == deviceId, let cachedContributedIDs {
            return cachedContributedIDs
        }

        let snapshot = try? await db.collection(FirestorePaths.watchlistDevicesCollection)
            .whereField("devices", arrayContains: deviceId)
            .getDocuments()
        let ids = Set(snapshot?.documents.map(\.documentID) ?? [])
        cachedContributedDeviceID = deviceId
        cachedContributedIDs = ids
        return ids
    }
    #else
    private func fetchContributedScreeningIDs() async -> Set<String> { [] }
    #endif

    private func invalidateContributionCache() {
        cachedContributedIDs = nil
        cachedContributedDeviceID = nil
    }

    private func legacyUserDefaultsContributedIDs(seasonYear: Int) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: "watchlistStatsContributed_\(seasonYear)") ?? [])
    }

    private func clearLegacyUserDefaultsContributions(seasonYear: Int) {
        UserDefaults.standard.removeObject(forKey: "watchlistStatsContributed_\(seasonYear)")
        UserDefaults.standard.removeObject(forKey: "watchlistStatsBackfillCompleted_\(seasonYear)")
    }

    private static func seasonYear(for screeningId: String) -> Int {
        guard screeningId.count >= 4, let year = Int(screeningId.prefix(4)) else {
            return FestivalProgramBootstrap.seasonYear
        }
        return year
    }

    private static func devices(from data: [String: Any]?) -> [String] {
        data?["devices"] as? [String] ?? []
    }

    private static func deviceCount(from data: [String: Any]?) -> Int {
        devices(from: data).count
    }

    private static func legacyCount(from data: [String: Any]?) -> Int {
        guard let raw = data?["count"] else { return 0 }
        if let value = raw as? Int { return max(0, value) }
        if let value = raw as? Int64 { return max(0, Int(value)) }
        if let value = raw as? NSNumber { return max(0, value.intValue) }
        if let value = raw as? Double { return max(0, Int(value)) }
        return 0
    }

    private func setCount(_ count: Int, for screeningId: String) {
        var updated = countByScreeningID
        if updated[screeningId] == count { return }
        updated[screeningId] = count
        countByScreeningID = updated
    }

    // MARK: - Keychain migration flag (survives reinstall; avoids repeat legacy −1)

    private static var hasCompletedDevicesSchemaV2Migration: Bool {
        readKeychainFlag(account: devicesSchemaV2MigrationKeychainAccount) == "1"
    }

    private static func markDevicesSchemaV2MigrationComplete() {
        saveKeychainFlag(account: devicesSchemaV2MigrationKeychainAccount, value: "1")
    }

    private static func readKeychainFlag(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "ch.heewhack.CineTransat.flags",
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func saveKeychainFlag(account: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "ch.heewhack.CineTransat.flags",
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update: [String: Any] = [kSecValueData as String: data]
            let match: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "ch.heewhack.CineTransat.flags",
                kSecAttrAccount as String: account,
            ]
            SecItemUpdate(match as CFDictionary, update as CFDictionary)
        }
    }
}
