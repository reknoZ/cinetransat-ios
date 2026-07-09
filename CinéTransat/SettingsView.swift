//
//  SettingsView.swift
//  CinéTransat
//

import SwiftUI
import MessageUI

struct SettingsView: View {
    @EnvironmentObject private var program: FestivalProgramStore
    @ObservedObject private var notificationManager = CancellationNotificationManager.shared
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var showFeedbackMail = false
    @State private var showFeedbackUnavailableAlert = false

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fr
    }

    private var navTitle: String {
        L10n.text("settings_title", language: appLanguage)
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: appLanguageRaw) ?? .fr },
            set: { appLanguageRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    settingsSection(title: L10n.text("settings_language", language: appLanguage)) {
                        Picker("", selection: languageBinding) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .accessibilityLabel(L10n.text("settings_language", language: appLanguage))
                    }

                    settingsSection(title: L10n.text("settings_notifications", language: appLanguage)) {
                        if notificationManager.authorizationStatus == .denied {
                            settingsFootnote(L10n.text("settings_notifications_denied", language: appLanguage))
                        } else {
                            Toggle(isOn: notificationsToggleBinding) {
                                Text(
                                    notificationManager.isEnabled
                                        ? L10n.text("settings_notifications_on", language: appLanguage)
                                        : L10n.text("settings_notifications_enable", language: appLanguage)
                                )
                                .foregroundStyle(Color.festivalAccent)
                            }
                            .tint(Color.festivalAccent)

                            settingsFootnote(L10n.text("settings_notifications_help", language: appLanguage))

                            if let status = notificationManager.deliveryStatusSummary(
                                language: appLanguage,
                                seasonYear: program.publicConfig.currentSeasonYear
                            ) {
                                settingsFootnote(
                                    status,
                                    color: notificationManager.lastTopicSubscribeError != nil
                                        ? .orange
                                        : Color.festivalAccent.opacity(0.8)
                                )
                            }
                        }
                    }

                    settingsSection(title: nil) {
                        settingsActionButton(L10n.text("settings_send_feedback", language: appLanguage)) {
                            openFeedback()
                        }
                        settingsActionButton(L10n.text("settings_rate_app", language: appLanguage)) {
                            if let url = AppSupport.appStoreReviewURL {
                                openURL(url)
                            }
                        }
                    }

                    settingsSection(title: L10n.text("settings_about_section", language: appLanguage)) {
                        HStack {
                            Text(L10n.text("settings_about_version", language: appLanguage))
                                .foregroundStyle(Color.festivalAccent)
                            Spacer()
                            Text(AppMetadata.versionLabel)
                                .foregroundStyle(Color.festivalAccent.opacity(0.8))
                                .monospacedDigit()
                        }

                        settingsFootnote(AppMetadata.copyright)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .festivalScreenBackground()
            .festivalPinkNavigationTitle(navTitle)
            .toolbarBackground(Color.festivalProgramBackground, for: .navigationBar)
            .tint(Color.festivalAccent)
            .sheet(isPresented: $showFeedbackMail) {
                MailComposeView(
                    recipients: [AppSupport.feedbackEmail],
                    subject: AppSupport.feedbackMailSubject(language: appLanguage),
                    body: AppSupport.feedbackMailBody(seasonYear: program.publicConfig.currentSeasonYear)
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
            .task {
                await notificationManager.refreshAuthorizationStatus()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task {
                        await notificationManager.refreshAuthorizationStatus()
                        await notificationManager.syncSubscriptionIfNeeded(
                            seasonYear: program.publicConfig.currentSeasonYear
                        )
                    }
                }
            }
        }
    }

    private func settingsSection<Content: View>(
        title: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.festivalAccent)
                    .textCase(nil)
            }
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .festivalCardChrome()
        }
    }

    private func settingsFootnote(_ text: String, color: Color = Color.festivalAccent.opacity(0.8)) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .foregroundStyle(Color.festivalAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var notificationsToggleBinding: Binding<Bool> {
        Binding(
            get: { notificationManager.isEnabled },
            set: { newValue in
                Task {
                    if newValue {
                        _ = await notificationManager.enableNotifications(
                            seasonYear: program.publicConfig.currentSeasonYear
                        )
                    } else {
                        await notificationManager.disableNotifications()
                    }
                }
            }
        )
    }

    private func openFeedback() {
        if MFMailComposeViewController.canSendMail() {
            showFeedbackMail = true
            return
        }
        if let url = AppSupport.feedbackMailtoURL(
            language: appLanguage,
            seasonYear: program.publicConfig.currentSeasonYear
        ) {
            openURL(url)
            return
        }
        showFeedbackUnavailableAlert = true
    }
}

private enum AppMetadata {
    static var versionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    static var copyright: String {
        if let notice = Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String,
           !notice.isEmpty {
            return notice
        }
        return "Copyright © \(Calendar.current.component(.year, from: Date())) Heewhack"
    }
}

#Preview {
    let stats = WatchListStatsStore()
    SettingsView()
        .environmentObject(FestivalProgramStore.preview)
        .environmentObject(WatchListStore.preview(statsStore: stats))
        .environmentObject(stats)
}
