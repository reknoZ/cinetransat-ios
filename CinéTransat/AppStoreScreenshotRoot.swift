//
//  AppStoreScreenshotRoot.swift
//  CinéTransat
//

import SwiftUI

/// Root UI used when the app is launched for App Store screenshot capture.
struct AppStoreScreenshotRoot: View {
    @EnvironmentObject private var program: FestivalProgramStore
    @EnvironmentObject private var watchList: WatchListStore
    @State private var isReady = false

    private let page = AppStoreScreenshotConfiguration.page

    var body: some View {
        Group {
            if isReady {
                screenshotContent
            } else {
                Color.festivalProgramBackground
                    .ignoresSafeArea()
            }
        }
        .environment(\.locale, Locale(identifier: AppLanguage.fr.localeIdentifier))
        .task {
            await AppStoreScreenshotConfiguration.prepareStores(program: program, watchList: watchList)
            isReady = true
        }
    }

    @ViewBuilder
    private var screenshotContent: some View {
        Group {
            switch page {
            case .program:
                ContentView(initialTab: .program)
                    .environment(\.appStoreScreenshotProgramWeekIndex, AppStoreScreenshotConfiguration.programWeekIndex)
            case .detail:
                NavigationStack {
                    MovieDetailView(
                        screening: AppStoreScreenshotConfiguration.showcaseScreening(in: program),
                        lineupScope: .fullProgram
                    )
                }
            case .watchlist:
                ContentView(initialTab: .watchlist)
            case .info:
                ContentView(initialTab: .info)
            case .festival:
                ContentView(initialTab: .festival)
            case .settings:
                ContentView(initialTab: .settings)
            }
        }
    }
}

private struct AppStoreScreenshotProgramWeekIndexKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

extension EnvironmentValues {
    var appStoreScreenshotProgramWeekIndex: Int? {
        get { self[AppStoreScreenshotProgramWeekIndexKey.self] }
        set { self[AppStoreScreenshotProgramWeekIndexKey.self] = newValue }
    }
}
