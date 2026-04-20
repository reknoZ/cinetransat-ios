//
//  SettingsView.swift
//  CinéTransat
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue
    @Environment(\.openURL) private var openURL

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

                Section {
                    NavigationLink(L10n.text("settings_about_app", language: appLanguage)) {
                        SettingsAboutAppView(appLanguage: appLanguage)
                    }

                    Button(L10n.text("settings_rate_app", language: appLanguage)) {
                        if let url = URL(string: "https://apps.apple.com/app/id0000000000") {
                            openURL(url)
                        }
                    }
                }
            }
            .navigationTitle(L10n.text("settings_title", language: appLanguage))
        }
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
