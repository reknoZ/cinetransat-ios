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
    @StateObject private var programNav = ProgramNavigationModel()
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
        _selectedTab = State(initialValue: tab == .today ? .program : tab)
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fr
    }

    private var showTodayTab: Bool {
        !AppStoreScreenshotConfiguration.isActive
            && !program.allScreenings.screeningsToday().isEmpty
    }

    private var todaysScreening: Screening? {
        program.allScreenings.screeningsToday().first
    }

    private var isViewingTodaysScreening: Bool {
        guard showTodayTab,
              let id = programNav.displayedDetailScreeningID,
              let today = todaysScreening else { return false }
        return id == today.id
    }

    /// Tab bar highlight: Today while the open detail is today's screening.
    private var highlightedTab: AppTab {
        if isViewingTodaysScreening { return .today }
        return selectedTab == .today ? .program : selectedTab
    }

    private var tabItems: [AppTab] {
        var items: [AppTab] = []
        if showTodayTab { items.append(.today) }
        items.append(.program)
        items.append(.watchlist)
        items.append(.info)
        if Self.isFestivalTabVisible { items.append(.festival) }
        items.append(.settings)
        return items
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .today, .program:
                    ProgramRootView(programFocusGeneration: programFocusGeneration)
                case .watchlist:
                    WatchListView()
                case .info:
                    UsefulInfoView()
                case .festival:
                    AboutFestivalView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)

            MainTabBar(
                items: tabItems,
                selection: highlightedTab,
                language: appLanguage,
                todayIconDay: todayTabIconDay,
                onSelect: handleTabSelect(_:)
            )
            .background {
                Color.festivalProgramBackground.ignoresSafeArea(edges: .bottom)
            }
        }
        .environmentObject(programNav)
        .festivalScreenBackground()
        .preferredColorScheme(.dark)
        .onAppear {
            if !Self.isFestivalTabVisible, selectedTab == .festival {
                selectedTab = .program
            }
            if !hasConfiguredInitialTab {
                if showTodayTab {
                    openTodaysScreening()
                    selectedTab = .program
                } else if selectedTab == .program, programFocusGeneration == 0 {
                    programFocusGeneration += 1
                }
                hasConfiguredInitialTab = true
            }
        }
        .onChange(of: showTodayTab) { _, isVisible in
            if !isVisible, selectedTab == .today {
                selectedTab = .program
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            todayTabIconDay = TodayTabBarIcon.dayOfMonth
        }
    }

    private func handleTabSelect(_ tab: AppTab) {
        switch tab {
        case .today:
            openTodaysScreening()
            selectedTab = .program
        case .program:
            selectedTab = .program
            programNav.popToRoot()
            programFocusGeneration += 1
        default:
            selectedTab = tab
        }
    }

    private func openTodaysScreening() {
        guard let screening = todaysScreening else { return }
        programFocusGeneration += 1
        programNav.open(screening)
    }
}

// MARK: - Tab bar

private struct MainTabBar: View {
    let items: [AppTab]
    let selection: AppTab
    let language: AppLanguage
    let todayIconDay: Int
    let onSelect: (AppTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    VStack(spacing: 4) {
                        tabIcon(tab)
                            .frame(height: 24)
                        Text(tabTitle(tab))
                            .font(.system(size: 10))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(tab == selection ? Color.festivalProgramTitle : Color.festivalAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tabTitle(tab))
                .accessibilityAddTraits(tab == selection ? .isSelected : [])
                .accessibilityIdentifier(accessibilityID(tab))
            }
        }
        .background(Color.festivalProgramBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.black.opacity(0.22))
                .frame(height: 1 / UIScreen.main.scale)
        }
    }

    @ViewBuilder
    private func tabIcon(_ tab: AppTab) -> some View {
        switch tab {
        case .today:
            Image(uiImage: TodayTabBarIcon.image(day: todayIconDay))
                .renderingMode(.template)
        case .program:
            Image(systemName: "calendar")
        case .watchlist:
            Image(systemName: "bookmark.fill")
        case .info:
            Image(systemName: "info.circle.fill")
        case .festival:
            Image(systemName: "sparkles")
        case .settings:
            Image(systemName: "gearshape.fill")
        }
    }

    private func tabTitle(_ tab: AppTab) -> String {
        switch tab {
        case .today: L10n.text("tab_today", language: language)
        case .program: L10n.text("tab_program", language: language)
        case .watchlist: L10n.text("tab_watchlist", language: language)
        case .info: L10n.text("tab_info", language: language)
        case .festival: L10n.text("tab_festival", language: language)
        case .settings: L10n.text("tab_settings", language: language)
        }
    }

    private func accessibilityID(_ tab: AppTab) -> String {
        switch tab {
        case .today: "tab_today"
        case .program: "tab_program"
        case .watchlist: "tab_watchlist"
        case .info: "tab_info"
        case .festival: "tab_festival"
        case .settings: "tab_settings"
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
