//
//  WatchListStatsStore.swift
//  CinéTransat
//
//  Anonymous aggregate counts: how many app users added a screening to their watch list.
//  No user IDs, tokens, or device identifiers are written to Firestore.
//

import Combine
import Foundation
import OSLog

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class WatchListStatsStore: ObservableObject {
    private static let logger = Logger(subsystem: "com.heewhack.CineTransat", category: "WatchListStats")

    /// Screening day key (`yyyyMMdd`) → anonymous headcount.
    @Published private(set) var countByScreeningID: [String: Int] = [:]

    #if canImport(FirebaseFirestore)
    private lazy var db = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]
    #endif

    private var activeSyncTask: Task<Void, Never>?

    func count(screeningId: String) -> Int? {
        countByScreeningID[screeningId]
    }

    /// Live count for one screening (e.g. film detail).
    func startObserving(screeningId: String) {
        guard !AppStoreScreenshotConfiguration.isActive else { return }
        #if canImport(FirebaseFirestore)
        guard listeners[screeningId] == nil else { return }
        let ref = db.document(FirestorePaths.watchlistStat(screeningId: screeningId))
        listeners[screeningId] = ref.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    Self.logger.error("Listener error (\(screeningId)): \(error.localizedDescription)")
                    return
                }
                let count = (snapshot?.data()?["count"] as? Int)
                    ?? (snapshot?.data()?["count"] as? NSNumber)?.intValue
                    ?? 0
                self.setCount(max(0, count), for: screeningId)
            }
        }
        #endif
    }

    func stopObserving(screeningId: String) {
        #if canImport(FirebaseFirestore)
        listeners[screeningId]?.remove()
        listeners[screeningId] = nil
        #endif
    }

    /// Keep live listeners in sync with a set of screening day keys (e.g. watch list rows).
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

    /// +1 when a user adds locally; −1 when they remove. Firestore rules only allow ±1 per write.
    @discardableResult
    func recordDelta(screeningId: String, seasonYear: Int, delta: Int) async -> Bool {
        guard delta == 1 || delta == -1 else { return false }
        guard !AppStoreScreenshotConfiguration.isActive else { return false }
        #if canImport(FirebaseFirestore)
        let path = FirestorePaths.watchlistStat(screeningId: screeningId)
        let ref = db.document(path)

        if delta == 1 {
            markContributed(seasonYear: seasonYear, screeningId: screeningId)
        } else {
            unmarkContributed(seasonYear: seasonYear, screeningId: screeningId)
        }

        do {
            let result = try await db.runTransaction { transaction, errorPointer -> Any? in
                let snapshot: DocumentSnapshot
                do {
                    snapshot = try transaction.getDocument(ref)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                let current = (snapshot.data()?["count"] as? Int)
                    ?? (snapshot.data()?["count"] as? NSNumber)?.intValue
                    ?? 0
                let next = current + delta
                guard next >= 0 else {
                    errorPointer?.pointee = NSError(
                        domain: "WatchListStats",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Count would become negative"]
                    )
                    return nil
                }

                transaction.setData(["count": next], forDocument: ref, merge: true)
                return next
            }

            let nextCount = (result as? Int) ?? (result as? NSNumber)?.intValue ?? 0
            setCount(max(0, nextCount), for: screeningId)
            Self.logger.info("Recorded Δ\(delta) for \(screeningId) at \(path) → \(nextCount)")
            return true
        } catch {
            if delta == 1 {
                unmarkContributed(seasonYear: seasonYear, screeningId: screeningId)
            } else {
                markContributed(seasonYear: seasonYear, screeningId: screeningId)
            }
            Self.logger.error("Write failed \(screeningId) Δ\(delta): \(error.localizedDescription)")
            return false
        }
        #else
        return false
        #endif
    }

    /// Align Firestore counts with this device's on-device watch list (including pre-upgrade entries).
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
        removeLegacyBackfillFlag(seasonYear: seasonYear)

        var contributed = contributedIDs(seasonYear: seasonYear)

        // User removed locally but we still think we contributed — send −1.
        for id in contributed where !screeningIDs.contains(id) {
            await recordDelta(screeningId: id, seasonYear: seasonYear, delta: -1)
            contributed.remove(id)
        }

        for id in screeningIDs {
            if contributed.contains(id) { continue }

            let remote = await remoteCount(screeningId: id)
            if remote > 0 {
                markContributed(seasonYear: seasonYear, screeningId: id)
                Self.logger.info("Adopted existing count \(remote) for \(id) without increment")
                continue
            }

            if await recordDelta(screeningId: id, seasonYear: seasonYear, delta: 1) {
                contributed.insert(id)
            }
        }
    }

    // MARK: - Per-device contribution ledger (not sent to Firebase)

    #if canImport(FirebaseFirestore)
    private func remoteCount(screeningId: String) async -> Int {
        let ref = db.document(FirestorePaths.watchlistStat(screeningId: screeningId))
        let snap = try? await ref.getDocument()
        guard let data = snap?.data() else { return 0 }
        return (data["count"] as? Int) ?? (data["count"] as? NSNumber)?.intValue ?? 0
    }
    #else
    private func remoteCount(screeningId: String) async -> Int { 0 }
    #endif

    private func contributedKey(seasonYear: Int) -> String {
        "watchlistStatsContributed_\(seasonYear)"
    }

    private func contributedIDs(seasonYear: Int) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: contributedKey(seasonYear: seasonYear)) ?? [])
    }

    private func markContributed(seasonYear: Int, screeningId: String) {
        var ids = contributedIDs(seasonYear: seasonYear)
        ids.insert(screeningId)
        UserDefaults.standard.set(Array(ids).sorted(), forKey: contributedKey(seasonYear: seasonYear))
    }

    private func unmarkContributed(seasonYear: Int, screeningId: String) {
        var ids = contributedIDs(seasonYear: seasonYear)
        ids.remove(screeningId)
        UserDefaults.standard.set(Array(ids).sorted(), forKey: contributedKey(seasonYear: seasonYear))
    }

    private func removeLegacyBackfillFlag(seasonYear: Int) {
        UserDefaults.standard.removeObject(forKey: "watchlistStatsBackfillCompleted_\(seasonYear)")
    }

    /// Assign a new dictionary so `@Published` emits and SwiftUI refreshes (subscript mutation does not).
    private func setCount(_ count: Int, for screeningId: String) {
        var updated = countByScreeningID
        if updated[screeningId] == count { return }
        updated[screeningId] = count
        countByScreeningID = updated
    }
}
