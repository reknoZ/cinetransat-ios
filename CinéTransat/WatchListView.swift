//
//  WatchListView.swift
//  CinéTransat
//

import SwiftUI

struct WatchListView: View {
    @EnvironmentObject private var program: FestivalProgramStore
    @EnvironmentObject private var watchList: WatchListStore
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue

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

    var body: some View {
        NavigationStack {
            Group {
                if listedScreenings.isEmpty {
                    ContentUnavailableView(
                        L10n.text("watchlist_empty_title", language: appLanguage),
                        systemImage: "bookmark",
                        description: Text(L10n.text("watchlist_empty_body", language: appLanguage))
                    )
                } else {
                    List(listedScreenings) { screening in
                        NavigationLink(value: screening) {
                            HStack(spacing: 12) {
                                MoviePosterCell(
                                    screening: screening,
                                    compact: true,
                                    posterWidth: 80,
                                    isOnWatchList: true,
                                    watchListEnabled: true,
                                    showDateBadge: false,
                                    onWatchListToggle: { watchList.toggle(screening, mayAdd: false) }
                                )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(screening.localizedTitle(language: appLanguage))
                                        .font(.headline)
                                        .foregroundStyle(screening.hasPassed ? Color.secondary : Color.primary)
                                        .lineLimit(2)
                                    Text(FestivalDateFormatters.mediumDate(screening.startsAt, language: appLanguage))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    if screening.hasPassed && !screening.isCanceled {
                                        Text(L10n.text("screening_passed", language: appLanguage))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(L10n.text("tab_watchlist", language: appLanguage))
            .navigationDestination(for: Screening.self) { screening in
                MovieDetailView(screening: screening, lineupScope: .watchListOnly)
            }
        }
    }
}

#Preview {
    WatchListView()
        .environmentObject(FestivalProgramStore.preview)
        .environmentObject(WatchListStore())
}
