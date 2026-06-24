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

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: appLanguageRaw) ?? .fr },
            set: { appLanguageRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section(L10n.text("settings_language", language: appLanguage)) {
                    Picker("", selection: languageBinding) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityLabel(L10n.text("settings_language", language: appLanguage))
                }

                Section(L10n.text("settings_notifications", language: appLanguage)) {
                    if notificationManager.authorizationStatus == .denied {
                        Text(L10n.text("settings_notifications_denied", language: appLanguage))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Toggle(isOn: notificationsToggleBinding) {
                            Text(
                                notificationManager.isEnabled
                                    ? L10n.text("settings_notifications_on", language: appLanguage)
                                    : L10n.text("settings_notifications_enable", language: appLanguage)
                            )
                        }
                        Text(L10n.text("settings_notifications_help", language: appLanguage))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if let status = notificationManager.deliveryStatusSummary(
                            language: appLanguage,
                            seasonYear: program.publicConfig.currentSeasonYear
                        ) {
                            Text(status)
                                .font(.footnote)
                                .foregroundStyle(
                                    notificationManager.lastTopicSubscribeError != nil ? .orange : .secondary
                                )
                        }
                    }
                }

                Section {
                    Button(L10n.text("settings_send_feedback", language: appLanguage)) {
                        openFeedback()
                    }

                    Button(L10n.text("settings_rate_app", language: appLanguage)) {
                        if let url = AppSupport.appStoreReviewURL {
                            openURL(url)
                        }
                    }
                }

                Section(L10n.text("settings_about_section", language: appLanguage)) {
                    LabeledContent(L10n.text("settings_about_version", language: appLanguage)) {
                        Text(AppMetadata.versionLabel)
                            .foregroundStyle(.secondary)
                    }
                    Text(AppMetadata.copyright)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(L10n.text("settings_title", language: appLanguage))
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
    SettingsView()
        .environmentObject(FestivalProgramStore.preview)
        .environmentObject(WatchListStore())
}
