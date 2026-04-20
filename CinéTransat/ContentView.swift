//
//  ContentView.swift
//  CinéTransat
//

import SwiftUI

struct ContentView: View {
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fr
    }

    var body: some View {
        TabView {
            ProgramRootView()
                .tabItem {
                    Label(L10n.text("tab_program", language: appLanguage), systemImage: "calendar")
                }

            WatchListView()
                .tabItem {
                    Label(L10n.text("tab_watchlist", language: appLanguage), systemImage: "bookmark.fill")
                }

            UsefulInfoView()
                .tabItem {
                    Label(L10n.text("tab_info", language: appLanguage), systemImage: "info.circle.fill")
                }

            AboutFestivalView()
                .tabItem {
                    Label(L10n.text("tab_festival", language: appLanguage), systemImage: "sparkles")
                }

            SettingsView()
                .tabItem {
                    Label(L10n.text("tab_settings", language: appLanguage), systemImage: "gearshape.fill")
                }
        }
    }
}

private struct AboutFestivalView: View {
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fr
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("CinéTransat")
                        .font(.largeTitle.weight(.bold))
                    Text(L10n.text("about_intro", language: appLanguage))
                        .font(.body)
                    Text(L10n.text("about_data_copy", language: appLanguage))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(L10n.text("about_poster_copy", language: appLanguage))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(L10n.text("about_title", language: appLanguage))
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchListStore())
}
