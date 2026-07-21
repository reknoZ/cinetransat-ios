//
//  WatchListStore.swift
//  CinéTransat
//

import Foundation
import SwiftUI
import Combine
import OSLog

/// Screenings the user marks as “planning to watch”. Stored on-device; anonymous aggregate
/// counts are synced to Firestore when the user adds or removes an entry.
@MainActor
final class WatchListStore: ObservableObject {
    private static let logger = Logger(subsystem: "com.heewhack.CineTransat", category: "WatchList")

    @Published private(set) var screeningIDs: Set<String>

    /// Kept for continuity with earlier builds (“favorites”).
    private let defaultsKey = "favorite_screening_ids"
    private let statsStore: WatchListStatsStore

    init(statsStore: WatchListStatsStore) {
        self.statsStore = statsStore
        let saved = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        screeningIDs = Set(saved)
    }

    func contains(_ screening: Screening) -> Bool {
        screeningIDs.contains(screening.watchListID)
    }

    func toggle(_ screening: Screening, seasonYear: Int, mayAdd: Bool = true) {
        guard !screening.hasPassed else { return }
        let id = screening.watchListID
        let delta: Int
        if screeningIDs.contains(id) {
            screeningIDs.remove(id)
            delta = -1
        } else if mayAdd {
            screeningIDs.insert(id)
            delta = 1
        } else {
            return
        }
        persist()
        enqueueStatsDelta(screeningId: id, delta: delta)
    }

    func replaceScreeningIDs(_ ids: Set<String>, persist shouldPersist: Bool = true) {
        screeningIDs = ids
        if shouldPersist {
            persist()
        }
    }

    func orderedWatchListScreenings(in weeks: [FestivalWeek]) -> [Screening] {
        weeks
            .flatMap(\.orderedScreenings)
            .filter { screeningIDs.contains($0.watchListID) }
            .sorted { $0.startsAt < $1.startsAt }
    }

    func syncAnonymousStatsWithLocalWatchList() async {
        await statsStore.onFirestoreServerReachable()
        let reconciled = await statsStore.syncWithLocalWatchList(screeningIDs)
        if reconciled != screeningIDs {
            replaceScreeningIDs(reconciled)
            Self.logger.info("Restored \(reconciled.count) screening(s) from Firestore")
        }
    }

    private func persist() {
        UserDefaults.standard.set(Array(screeningIDs).sorted(), forKey: defaultsKey)
    }

    private func enqueueStatsDelta(screeningId: String, delta: Int) {
        statsStore.applyOptimisticDelta(screeningId: screeningId, delta: delta)
        Task {
            await statsStore.recordDelta(screeningId: screeningId, delta: delta)
        }
    }
}

extension WatchListStore {
    /// Preview / tests without Firestore.
    @MainActor
    static func preview(statsStore: WatchListStatsStore) -> WatchListStore {
        WatchListStore(statsStore: statsStore)
    }
}
