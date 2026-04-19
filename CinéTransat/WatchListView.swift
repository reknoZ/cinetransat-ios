//
//  WatchListView.swift
//  CinéTransat
//

import SwiftUI

struct WatchListView: View {
    @EnvironmentObject private var watchList: WatchListStore

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_CH")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        NavigationStack {
            Group {
                if watchList.orderedWatchListScreenings.isEmpty {
                    ContentUnavailableView(
                        "Nothing on your watch list yet",
                        systemImage: "bookmark",
                        description: Text("Long-press a poster in Programme to mark a screening you plan to see.")
                    )
                } else {
                    List(watchList.orderedWatchListScreenings) { screening in
                        NavigationLink(value: screening) {
                            HStack(spacing: 12) {
                                MoviePosterCell(
                                    screening: screening,
                                    compact: true,
                                    posterWidth: 80,
                                    isOnWatchList: true,
                                    showDateBadge: false
                                )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(screening.title)
                                        .font(.headline)
                                        .lineLimit(2)
                                    Text(Self.dateFormatter.string(from: screening.startsAt))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Watch List")
            .navigationDestination(for: Screening.self) { screening in
                MovieDetailView(screening: screening, lineupScope: .watchListOnly)
            }
        }
    }
}

#Preview {
    WatchListView()
        .environmentObject(WatchListStore())
}
