//
//  AppStoreScreenshotConfiguration.swift
//  CinéTransat
//
//  Launch with `-AppStoreScreenshots -ScreenshotPage program` (etc.) to render
//  stable screens for App Store capture. Used by `scripts/capture_app_store_screenshots.sh`.
//

import Foundation

enum AppStoreScreenshotConfiguration {
    enum Page: String, CaseIterable {
        case program
        case detail
        case watchlist
        case info
        case festival
        case settings
    }

    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-AppStoreScreenshots")
    }

    static var page: Page {
        guard isActive,
              let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-ScreenshotPage"),
              index + 1 < ProcessInfo.processInfo.arguments.count,
              let page = Page(rawValue: ProcessInfo.processInfo.arguments[index + 1]) else {
            return .program
        }
        return page
    }

    /// Zero-based week index on the programme tab.
    static var programWeekIndex: Int {
        guard isActive,
              let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-ScreenshotWeek"),
              index + 1 < ProcessInfo.processInfo.arguments.count,
              let week = Int(ProcessInfo.processInfo.arguments[index + 1]) else {
            return 0
        }
        return max(0, week)
    }

    static func prepareEnvironment() {
        guard isActive else { return }
        UserDefaults.standard.set(AppLanguage.fr.rawValue, forKey: "appLanguage")
        UserDefaults.standard.removeObject(forKey: "knownCanceledScreeningIDs")
        UserDefaults.standard.removeObject(forKey: "favorite_screening_ids")
        UserDefaults.standard.set(true, forKey: "initialNotificationPromptCompleted")
    }

    @MainActor
    static func prepareStores(program: FestivalProgramStore, watchList: WatchListStore) {
        guard isActive else { return }
        program.prepareBundledDataForScreenshots()
        let ids = [
            "20250710", // Les Bronzés
            "20250717", // E.T.
            "20250726", // Paddington 2
        ]
        watchList.replaceScreeningIDs(Set(ids), persist: false)
    }

    @MainActor
    static func showcaseScreening(in program: FestivalProgramStore) -> Screening {
        program.allScreenings.first { $0.title == "E.T. l'extra-terrestre" }
            ?? program.allScreenings.first!
    }
}
