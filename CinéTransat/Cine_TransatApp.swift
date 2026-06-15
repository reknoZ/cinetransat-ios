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
    @StateObject private var watchListStore: WatchListStore
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fr
    }

    init() {
        AppStoreScreenshotConfiguration.prepareEnvironment()
        if !AppStoreScreenshotConfiguration.isActive {
            FirebaseApp.configure()
            CancellationNotificationManager.installDelegates()
        }
        _programStore = StateObject(wrappedValue: FestivalProgramStore(startListeners: false))
        _watchListStore = StateObject(wrappedValue: WatchListStore())
    }

    var body: some Scene {
        WindowGroup {
            RootWithLaunchSplash()
                .environmentObject(programStore)
                .environmentObject(watchListStore)
                .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        }
    }
}

private struct RootWithLaunchSplash: View {
    @EnvironmentObject private var programStore: FestivalProgramStore
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
    }

    private func beginPostLaunchLoading() {
        withAnimation(.easeOut(duration: 0.2)) {
            launchIsLoading = true
        }
        Task {
            await programStore.completePostLaunchSetup()
            withAnimation(.easeOut(duration: 0.25)) {
                showSplash = false
            }
            await CancellationNotificationManager.shared.promptForNotificationsOnFirstLaunchIfNeeded(
                seasonYear: programStore.publicConfig.currentSeasonYear
            )
        }
    }
}
