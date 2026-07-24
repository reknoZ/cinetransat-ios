//
//  ProgramNavigationModel.swift
//  CinéTransat
//

import Combine
import SwiftUI

/// Shared program navigation so Today can open today's screening inside the Program stack.
@MainActor
final class ProgramNavigationModel: ObservableObject {
    @Published var path = NavigationPath()
    @Published var weekIndex = 0
    @Published var selectedWeek: FestivalWeek?
    @Published var displayedDetailScreeningID: String?
    /// Bumped to request opening `pendingScreening` inside the program stack.
    @Published private(set) var openToken = 0

    private(set) var pendingScreening: Screening?

    func open(_ screening: Screening) {
        pendingScreening = screening
        openToken += 1
    }

    func applyPendingOpenIfNeeded() {
        guard let screening = pendingScreening else { return }
        pendingScreening = nil
        var next = NavigationPath()
        next.append(screening)
        path = next
        displayedDetailScreeningID = screening.id
    }

    func popToRoot() {
        path = NavigationPath()
        displayedDetailScreeningID = nil
    }
}
