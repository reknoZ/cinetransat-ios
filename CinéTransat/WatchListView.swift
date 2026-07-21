//
//  WatchListView.swift
//  CinéTransat
//

import SwiftUI

struct WatchListView: View {
    @EnvironmentObject private var program: FestivalProgramStore
    @EnvironmentObject private var watchList: WatchListStore
    @EnvironmentObject private var watchListStats: WatchListStatsStore
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue
    @State private var isAddingAllToCalendar = false
    @State private var calendarResultAlert: CalendarResultAlert?
    @State private var pendingRemovalId: String?
    @State private var removalSecondsLeft = 5

    private static let removalDelaySeconds = 5

    private enum CalendarResultAlert: Identifiable {
        case denied
        case empty
        case added(count: Int)
        case partial(added: Int, failed: Int)

        var id: String {
            switch self {
            case .denied: return "denied"
            case .empty: return "empty"
            case .added(let count): return "added-\(count)"
            case .partial(let added, let failed): return "partial-\(added)-\(failed)"
            }
        }
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fr
    }

    private var listedScreenings: [Screening] {
        let activeYear = program.publicConfig.currentSeasonYear
        let yearPrefix = String(activeYear)
        return watchList
            .orderedWatchListScreenings(in: program.weeks)
            .filter { $0.isProgramAnnounced && $0.id.hasPrefix(yearPrefix) }
    }

    private var listedScreeningIDs: Set<String> {
        Set(listedScreenings.map(\.id))
    }

    private func othersCount(for screening: Screening) -> Int? {
        guard let total = watchListStats.count(screeningId: screening.id) else { return nil }
        let others = WatchListStatsStore.othersCount(total: total, inWatchList: true)
        return others > 0 ? others : nil
    }

    var body: some View {
        NavigationStack {
            Group {
                if listedScreenings.isEmpty {
                    watchListEmptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(listedScreenings) { screening in
                                NavigationLink(value: screening) {
                                    watchListRow(for: screening)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
            .festivalScreenBackground()
            .navigationTitle(L10n.text("tab_watchlist", language: appLanguage))
            .toolbarBackground(Color.festivalProgramBackground, for: .navigationBar)
            .tint(Color.festivalAccent)
            .toolbar {
                if !listedScreenings.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task { await addAllToCalendar() }
                        } label: {
                            Label(
                                L10n.text("calendar_add_all", language: appLanguage),
                                systemImage: "calendar.badge.plus"
                            )
                        }
                        .disabled(isAddingAllToCalendar)
                    }
                }
            }
            .navigationDestination(for: Screening.self) { screening in
                MovieDetailView(screening: screening, lineupScope: .watchListOnly)
            }
            .onAppear {
                watchListStats.syncObservations(screeningIds: listedScreeningIDs)
            }
            .onChange(of: listedScreeningIDs) { _, ids in
                watchListStats.syncObservations(screeningIds: ids)
            }
            .onDisappear {
                watchListStats.stopAllObservations()
                pendingRemovalId = nil
            }
            .task(id: pendingRemovalId) {
                guard let id = pendingRemovalId else { return }
                for seconds in stride(from: Self.removalDelaySeconds, through: 1, by: -1) {
                    removalSecondsLeft = seconds
                    try? await Task.sleep(for: .seconds(1))
                    if Task.isCancelled { return }
                }
                guard pendingRemovalId == id,
                      let screening = listedScreenings.first(where: { $0.id == id }) else { return }
                watchList.toggle(screening, seasonYear: program.seasonYear, mayAdd: false)
                pendingRemovalId = nil
            }
            .alert(item: $calendarResultAlert) { alert in
                switch alert {
                case .denied:
                    Alert(
                        title: Text(L10n.text("calendar_add_all", language: appLanguage)),
                        message: Text(L10n.text("calendar_access_denied", language: appLanguage)),
                        dismissButton: .default(Text("OK"))
                    )
                case .empty:
                    Alert(
                        title: Text(L10n.text("calendar_add_all", language: appLanguage)),
                        message: Text(L10n.text("calendar_nothing_to_add", language: appLanguage)),
                        dismissButton: .default(Text("OK"))
                    )
                case .added(let count):
                    Alert(
                        title: Text(L10n.text("calendar_add_all", language: appLanguage)),
                        message: Text(
                            String(format: L10n.text("calendar_added_all", language: appLanguage), count)
                        ),
                        dismissButton: .default(Text("OK"))
                    )
                case .partial(let added, let failed):
                    Alert(
                        title: Text(L10n.text("calendar_add_all", language: appLanguage)),
                        message: Text(
                            String(format: L10n.text("calendar_added_partial", language: appLanguage), added, failed)
                        ),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
    }

    private var watchListEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.festivalAccent)

            Text(L10n.text("watchlist_empty_title", language: appLanguage))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.festivalAccent)

            Text(L10n.text("watchlist_empty_body", language: appLanguage))
                .font(.body)
                .foregroundStyle(Color.festivalAccent.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func watchListRow(for screening: Screening) -> some View {
        let isPendingRemoval = pendingRemovalId == screening.id

        return HStack(spacing: 12) {
            MoviePosterCell(
                screening: screening,
                compact: true,
                posterWidth: 80,
                isOnWatchList: true,
                watchListEnabled: true,
                showDateBadge: false,
                isPendingRemoval: isPendingRemoval,
                removalSecondsLeft: removalSecondsLeft,
                onWatchListToggle: screening.hasPassed
                    ? nil
                    : {
                        if isPendingRemoval {
                            pendingRemovalId = nil
                        } else {
                            pendingRemovalId = screening.id
                            removalSecondsLeft = Self.removalDelaySeconds
                        }
                    }
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(screening.localizedTitle(language: appLanguage))
                    .font(.headline)
                    .foregroundStyle(
                        screening.hasPassed
                            ? Color.festivalAccent.opacity(0.55)
                            : Color.festivalAccent
                    )
                    .lineLimit(2)

                Text(FestivalDateFormatters.mediumDate(screening.startsAt, language: appLanguage))
                    .font(.subheadline)
                    .foregroundStyle(Color.festivalAccent.opacity(0.8))

                if screening.hasPassed && !screening.isCanceled {
                    Text(L10n.text("screening_passed", language: appLanguage))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.festivalAccent.opacity(0.65))
                }

                if let others = othersCount(for: screening) {
                    Text(L10n.watchlistOthers(others, language: appLanguage))
                        .font(.caption)
                        .foregroundStyle(Color.festivalAccent.opacity(0.65))
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.festivalAccent.opacity(0.55))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.festivalProgramBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.festivalAccent.opacity(0.22), lineWidth: 1)
        }
    }

    private func addAllToCalendar() async {
        isAddingAllToCalendar = true
        defer { isAddingAllToCalendar = false }

        let result = await ScreeningCalendarService.addUpcomingScreenings(
            listedScreenings,
            language: appLanguage
        )
        switch result {
        case .denied:
            calendarResultAlert = .denied
        case .empty:
            calendarResultAlert = .empty
        case .added(let count):
            calendarResultAlert = .added(count: count)
        case .partial(let added, let failed):
            calendarResultAlert = .partial(added: added, failed: failed)
        }
    }
}

#Preview {
    let stats = WatchListStatsStore()
    WatchListView()
        .environmentObject(FestivalProgramStore.preview)
        .environmentObject(WatchListStore.preview(statsStore: stats))
        .environmentObject(stats)
}
