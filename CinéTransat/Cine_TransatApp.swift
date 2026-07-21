//
//  Cine_TransatApp.swift
//  CinéTransat
//
//  Created by David on 4/18/26.
//

import SwiftUI
import FirebaseCore
import MessageUI
import UIKit

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
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue
    @ObservedObject private var reviewPrompt = AppReviewPromptController.shared
    @State private var showSplash = true
    @State private var launchIsLoading = false
    @State private var showFeedbackMail = false
    @State private var showFeedbackUnavailableAlert = false

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fr
    }

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
            if showSplash {
                if phase != .active {
                    reviewPrompt.handleScenePhase(phase)
                }
            } else {
                reviewPrompt.handleScenePhase(phase)
            }
            guard phase == .active, !showSplash else { return }
            Task {
                await watchList.syncAnonymousStatsWithLocalWatchList()
            }
        }
        .onChange(of: showSplash) { _, isShowing in
            if !isShowing, scenePhase == .active {
                reviewPrompt.handleScenePhase(.active)
            }
        }
        .sheet(
            isPresented: $reviewPrompt.isPresentingPrompt,
            onDismiss: { reviewPrompt.handleSheetDismissed() }
        ) {
            AppReviewPromptSheet(
                language: appLanguage,
                onSubmit: { stars in
                    reviewPrompt.submitRating(
                        stars,
                        seasonYear: programStore.publicConfig.currentSeasonYear
                    )
                },
                onNotNow: { reviewPrompt.dismissWithoutAction() }
            )
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
        .onChange(of: reviewPrompt.pendingFeedbackSeasonYear) { _, year in
            guard let year else { return }
            reviewPrompt.clearPendingFeedback()
            openFeedback(seasonYear: year)
        }
        .sheet(isPresented: $showFeedbackMail) {
            MailComposeView(
                recipients: [AppSupport.feedbackEmail],
                subject: AppSupport.feedbackMailSubject(language: appLanguage),
                body: AppSupport.feedbackMailBody(
                    seasonYear: programStore.publicConfig.currentSeasonYear
                )
            )
        }
        .alert(
            L10n.text("settings_send_feedback", language: appLanguage),
            isPresented: $showFeedbackUnavailableAlert
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                String(
                    format: L10n.text("settings_feedback_unavailable", language: appLanguage),
                    AppSupport.feedbackEmail
                )
            )
        }
    }

    private func openFeedback(seasonYear: Int) {
        if MFMailComposeViewController.canSendMail() {
            showFeedbackMail = true
            return
        }
        if let url = AppSupport.feedbackMailtoURL(language: appLanguage, seasonYear: seasonYear) {
            UIApplication.shared.open(url)
            return
        }
        showFeedbackUnavailableAlert = true
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
