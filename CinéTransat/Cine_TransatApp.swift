//
//  Cine_TransatApp.swift
//  CinéTransat
//
//  Created by David on 4/18/26.
//

import SwiftUI
import FirebaseCore

@main
struct Cine_TransatApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var programStore: FestivalProgramStore
    @StateObject private var watchListStatsStore: WatchListStatsStore
    @StateObject private var watchListStore: WatchListStore
    @StateObject private var rattrapageVotesStore = RattrapageVotesStore()
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fr
    }

    init() {
        AppStoreScreenshotConfiguration.prepareEnvironment()
        let statsStore = WatchListStatsStore()
        _watchListStatsStore = StateObject(wrappedValue: statsStore)
        _watchListStore = StateObject(wrappedValue: WatchListStore(statsStore: statsStore))
        if !AppStoreScreenshotConfiguration.isActive {
            FirebaseApp.configure()
            CancellationNotificationManager.installDelegates()
        }
        FestivalAppearance.configure()
        _programStore = StateObject(wrappedValue: FestivalProgramStore(startListeners: false))
    }

    var body: some Scene {
        WindowGroup {
            RootWithLaunchSplash()
                .environmentObject(programStore)
                .environmentObject(watchListStore)
                .environmentObject(watchListStatsStore)
                .environmentObject(rattrapageVotesStore)
                .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
                .tint(Color.festivalAccent)
        }
    }
}

private struct RootWithLaunchSplash: View {
    @EnvironmentObject private var programStore: FestivalProgramStore
    @EnvironmentObject private var watchList: WatchListStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash = true
    @State private var launchIsLoading = false

    var body: some View {
        ZStack {
            if AppStoreScreenshotConfiguration.isActive {
                AppStoreScreenshotRoot()
            } else if !showSplash {
                ContentView()
                    .transition(.opacity)
            }

            if showSplash, !AppStoreScreenshotConfiguration.isActive {
                FestivalLaunchSplashView(isLoading: $launchIsLoading) {
                    beginPostLaunchLoading()
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, !showSplash else { return }
            Task {
                await watchList.syncAnonymousStatsWithLocalWatchList()
            }
        }
    }

    private func beginPostLaunchLoading() {
        withAnimation(.easeOut(duration: 0.2)) {
            launchIsLoading = true
        }
        Task {
            await programStore.completePostLaunchSetup()
            await watchList.syncAnonymousStatsWithLocalWatchList()
            withAnimation(.easeOut(duration: 0.25)) {
                showSplash = false
            }
            await CancellationNotificationManager.shared.promptForNotificationsOnFirstLaunchIfNeeded(
                seasonYear: programStore.publicConfig.currentSeasonYear
            )
        }
    }
}
