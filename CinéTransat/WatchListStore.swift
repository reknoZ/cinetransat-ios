//
//  WatchListStore.swift
//  CinéTransat
//

import Foundation
import SwiftUI
import Combine

/// Screenings the user marks as “planning to watch”. Stored on-device; anonymous aggregate
/// counts are synced to Firestore when the user adds or removes an entry.
@MainActor
final class WatchListStore: ObservableObject {
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
        let id = screening.watchListID
        if screeningIDs.contains(id) {
            screeningIDs.remove(id)
            persist()
            Task { await statsStore.recordDelta(screeningId: id, seasonYear: seasonYear, delta: -1) }
        } else if mayAdd {
            screeningIDs.insert(id)
            persist()
            Task { await statsStore.recordDelta(screeningId: id, seasonYear: seasonYear, delta: 1) }
        }
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

    func syncAnonymousStatsWithLocalWatchList(seasonYear: Int) async {
        await statsStore.syncWithLocalWatchList(screeningIDs, seasonYear: seasonYear)
    }

    private func persist() {
        UserDefaults.standard.set(Array(screeningIDs).sorted(), forKey: defaultsKey)
    }
}

extension WatchListStore {
    /// Preview / tests without Firestore.
    @MainActor
    static func preview(statsStore: WatchListStatsStore) -> WatchListStore {
        WatchListStore(statsStore: statsStore)
    }
}
