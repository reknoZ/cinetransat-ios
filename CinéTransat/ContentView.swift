//
//  ContentView.swift
//  CinéTransat
//

import SwiftUI

enum AppTab: Hashable {
    case program
    case watchlist
    case info
    case festival
    case settings
}

struct ContentView: View {
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue
    @State private var selectedTab: AppTab

    init(initialTab: AppTab = .program) {
        _selectedTab = State(initialValue: initialTab)
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fr
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ProgramRootView()
                .tabItem {
                    Label(L10n.text("tab_program", language: appLanguage), systemImage: "calendar")
                }
                .tag(AppTab.program)
                .accessibilityIdentifier("tab_program")

            WatchListView()
                .tabItem {
                    Label(L10n.text("tab_watchlist", language: appLanguage), systemImage: "bookmark.fill")
                }
                .tag(AppTab.watchlist)
                .accessibilityIdentifier("tab_watchlist")

            UsefulInfoView()
                .tabItem {
                    Label(L10n.text("tab_info", language: appLanguage), systemImage: "info.circle.fill")
                }
                .tag(AppTab.info)
                .accessibilityIdentifier("tab_info")

            AboutFestivalView()
                .tabItem {
                    Label(L10n.text("tab_festival", language: appLanguage), systemImage: "sparkles")
                }
                .tag(AppTab.festival)
                .accessibilityIdentifier("tab_festival")

            SettingsView()
                .tabItem {
                    Label(L10n.text("tab_settings", language: appLanguage), systemImage: "gearshape.fill")
                }
                .tag(AppTab.settings)
                .accessibilityIdentifier("tab_settings")
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
                }
                .padding()
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(L10n.text("tab_festival", language: appLanguage))
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(FestivalProgramStore.preview)
        .environmentObject(WatchListStore())
}
