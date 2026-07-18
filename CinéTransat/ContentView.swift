//
//  ContentView.swift
//  CinéTransat
//

import SwiftUI

enum AppTab: Hashable {
    case today
    case program
    case watchlist
    case info
    case festival
    case settings
}

struct ContentView: View {
    /// Set to `true` when the voting / festival tab ships.
    private static let isFestivalTabVisible = false

    @EnvironmentObject private var program: FestivalProgramStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue
    @State private var selectedTab: AppTab
    @State private var programFocusGeneration = 0
    @State private var hasConfiguredInitialTab = false
    @State private var todayTabIconDay = TodayTabBarIcon.dayOfMonth

    init(initialTab: AppTab = .program) {
        let tab: AppTab
        if Self.isFestivalTabVisible {
            tab = initialTab
        } else if initialTab == .festival {
            tab = .program
        } else {
            tab = initialTab
        }
        _selectedTab = State(initialValue: tab)
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fr
    }

    private var showTodayTab: Bool {
        !AppStoreScreenshotConfiguration.isActive
            && !program.allScreenings.screeningsToday().isEmpty
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            if showTodayTab {
                TodayTabView()
                    .tabItem {
                        Image(uiImage: TodayTabBarIcon.image(day: todayTabIconDay))
                        Text(L10n.text("tab_today", language: appLanguage))
                    }
                    .tag(AppTab.today)
                    .accessibilityIdentifier("tab_today")
            }

            ProgramRootView(programFocusGeneration: programFocusGeneration)
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

            if Self.isFestivalTabVisible {
                AboutFestivalView()
                    .tabItem {
                        Label(L10n.text("tab_festival", language: appLanguage), systemImage: "sparkles")
                    }
                    .tag(AppTab.festival)
                    .accessibilityIdentifier("tab_festival")
            }

            SettingsView()
                .tabItem {
                    Label(L10n.text("tab_settings", language: appLanguage), systemImage: "gearshape.fill")
                }
                .tag(AppTab.settings)
                .accessibilityIdentifier("tab_settings")
        }
        .festivalScreenBackground()
        .preferredColorScheme(.dark)
        .toolbarBackground(Color.festivalProgramBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .onAppear {
            if !Self.isFestivalTabVisible, selectedTab == .festival {
                selectedTab = .program
            }
            if !hasConfiguredInitialTab {
                if showTodayTab, selectedTab == .program {
                    selectedTab = .today
                }
                hasConfiguredInitialTab = true
            }
            if !showTodayTab, selectedTab == .program, programFocusGeneration == 0 {
                programFocusGeneration += 1
            }
        }
        .onChange(of: showTodayTab) { _, isVisible in
            if !isVisible, selectedTab == .today {
                selectedTab = .program
            }
        }
        .onChange(of: selectedTab) { _, tab in
            if tab == .program {
                programFocusGeneration += 1
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            todayTabIconDay = TodayTabBarIcon.dayOfMonth
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
            .festivalScreenBackground()
        }
    }
}

#Preview {
    let stats = WatchListStatsStore()
    ContentView()
        .environmentObject(FestivalProgramStore.preview)
        .environmentObject(WatchListStore.preview(statsStore: stats))
        .environmentObject(stats)
        .environmentObject(RattrapageVotesStore())
}
