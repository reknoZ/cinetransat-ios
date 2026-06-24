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
    static func prepareStores(program: FestivalProgramStore, watchList: WatchListStore) async {
        guard isActive else { return }
        program.prepareBundledDataForScreenshots()
        let ids = [
            "20260709", // Back to the Future
            "20260710", // La Famille Bélier
            "20260711", // Billy Elliot
        ]
        watchList.replaceScreeningIDs(Set(ids), persist: false)

        let weekOnePosterKeys = Set(
            program.weeks.first?.orderedScreenings
                .filter { !$0.usesTBDPlaceholderPoster }
                .map(\.posterKey) ?? []
        )
        _ = await program.prefetchPostersForCurrentSeason(posterKeysFilter: weekOnePosterKeys.isEmpty ? nil : weekOnePosterKeys)
        if page == .detail || page == .watchlist {
            let detailKeys = Set([showcaseScreening(in: program).posterKey])
            _ = await program.prefetchPostersForCurrentSeason(posterKeysFilter: detailKeys)
        }
    }

    @MainActor
    static func showcaseScreening(in program: FestivalProgramStore) -> Screening {
        program.allScreenings.first { $0.title == "Back to the Future" }
            ?? program.allScreenings.first!
    }
}
