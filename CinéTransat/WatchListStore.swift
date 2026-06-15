//
//  WatchListStore.swift
//  CinéTransat
//

import Foundation
import SwiftUI
import Combine

/// Screenings the user marks as “planning to watch”. Stored on-device only.
///
/// A **total audience / headcount** for each screening needs a synced backend
/// (e.g. Firestore document per `Screening.watchListID` with an aggregate counter).
/// This store does not claim to represent other people’s plans.
@MainActor
final class WatchListStore: ObservableObject {
    @Published private(set) var screeningIDs: Set<String>

    /// Kept for continuity with earlier builds (“favorites”).
    private let defaultsKey = "favorite_screening_ids"

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        screeningIDs = Set(saved)
    }

    func contains(_ screening: Screening) -> Bool {
        screeningIDs.contains(screening.watchListID)
    }

    func toggle(_ screening: Screening, mayAdd: Bool = true) {
        let id = screening.watchListID
        if screeningIDs.contains(id) {
            screeningIDs.remove(id)
        } else if mayAdd {
            screeningIDs.insert(id)
        }
        persist()
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

    private func persist() {
        UserDefaults.standard.set(Array(screeningIDs).sorted(), forKey: defaultsKey)
    }
}
