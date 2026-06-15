//
//  SettingsView.swift
//  CinéTransat
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var program: FestivalProgramStore
    @ObservedObject private var notificationManager = CancellationNotificationManager.shared
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var exportFileURL: URL?
    @State private var showShareSheet = false
    @State private var exportErrorMessage: String?

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fr
    }

    var body: some View {
        NavigationStack {
            List {
                Section(L10n.text("settings_language", language: appLanguage)) {
                    HStack {
                        Text(L10n.text("settings_language", language: appLanguage))
                        Spacer()
                        Menu {
                            ForEach(AppLanguage.allCases) { language in
                                Button {
                                    appLanguageRaw = language.rawValue
                                } label: {
                                    Text(language.displayName)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(appLanguage.displayName)
                                Image(systemName: "chevron.down")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.primary)
                        }
                    }

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
                        Text(
                            "Topic: \(CancellationNotificationManager.cancellationTopic(seasonYear: program.publicConfig.currentSeasonYear)) — edit Firestore seasons/\(program.publicConfig.currentSeasonYear) only.",
                            comment: "FCM topic hint for debugging"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        if let err = notificationManager.lastTopicSubscribeError {
                            Text(err)
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section {
                    NavigationLink(L10n.text("settings_about_app", language: appLanguage)) {
                        SettingsAboutAppView(appLanguage: appLanguage)
                    }

                    Button(L10n.text("settings_rate_app", language: appLanguage)) {
                        if let url = URL(string: "https://apps.apple.com/app/id0000000000") {
                            openURL(url)
                        }
                    }

                    Button(L10n.text("settings_export_data", language: appLanguage)) {
                        exportProgramData()
                    }
                }
            }
            .navigationTitle(L10n.text("settings_title", language: appLanguage))
            .task {
                await notificationManager.refreshAuthorizationStatus()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await notificationManager.refreshAuthorizationStatus() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportFileURL {
                    ActivityViewController(activityItems: [url])
                }
            }
            .alert(
                L10n.text("settings_export_error_title", language: appLanguage),
                isPresented: Binding(
                    get: { exportErrorMessage != nil },
                    set: { isPresented in
                        if !isPresented { exportErrorMessage = nil }
                    }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportErrorMessage ?? "")
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

    private func exportProgramData() {
        do {
            let data = try program.exportProgramSeedJSONData()
            let fileURL = try writeTempExportFile(data: data)
            exportFileURL = fileURL
            showShareSheet = true
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func writeTempExportFile(data: Data) throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cinetransat-export-\(stamp).json")
        try data.write(to: url, options: .atomic)
        return url
    }
}

private struct SettingsAboutAppView: View {
    let appLanguage: AppLanguage

    var body: some View {
        ScrollView {
            Text(L10n.text("settings_about_copy", language: appLanguage))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(L10n.text("settings_about_app", language: appLanguage))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
