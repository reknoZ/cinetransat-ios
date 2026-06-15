//
//  MovieDetailView.swift
//  CinéTransat
//

import SwiftUI

/// Which ordered list prev/next controls move through on the detail screen.
enum MovieDetailLineupScope: Hashable {
    case fullProgram
    case watchListOnly
}

struct MovieDetailView: View {
    @EnvironmentObject private var program: FestivalProgramStore
    @EnvironmentObject private var watchList: WatchListStore
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue

    let lineupScope: MovieDetailLineupScope
    @State private var screening: Screening

    init(screening: Screening, lineupScope: MovieDetailLineupScope = .fullProgram) {
        self.lineupScope = lineupScope
        _screening = State(initialValue: screening)
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fr
    }

    private var navigableLineup: [Screening] {
        switch lineupScope {
        case .fullProgram:
            program.allScreenings
        case .watchListOnly:
            watchList.orderedWatchListScreenings(in: program.weeks)
        }
    }

    private var lineupIndex: Int? {
        navigableLineup.firstIndex { $0.watchListID == screening.watchListID }
    }

    private var previousScreening: Screening? {
        guard let i = lineupIndex, i > 0 else { return nil }
        return navigableLineup[i - 1]
    }

    private var nextScreening: Screening? {
        guard let i = lineupIndex, i + 1 < navigableLineup.count else { return nil }
        return navigableLineup[i + 1]
    }

    private func watchListToggleAction(for screening: Screening) -> (() -> Void)? {
        let mayAdd = program.canAddToWatchList(screening)
        guard mayAdd || watchList.contains(screening) else { return nil }
        return { watchList.toggle(screening, mayAdd: mayAdd) }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_CH")
        f.dateStyle = .full
        f.timeStyle = .none
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_CH")
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 12) {
                    if let prev = previousScreening {
                        Button {
                            screening = prev
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title2.weight(.semibold))
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Film précédent")
                    } else {
                        Image(systemName: "chevron.left")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityHidden(true)
                    }

                    MoviePosterCell(
                        screening: screening,
                        compact: false,
                        isOnWatchList: watchList.contains(screening),
                        watchListEnabled: program.canAddToWatchList(screening),
                        onWatchListToggle: watchListToggleAction(for: screening)
                    )
                    .id(screening.id)
                    .frame(maxWidth: 280)

                    if let next = nextScreening {
                        Button {
                            screening = next
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.title2.weight(.semibold))
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Film suivant")
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    if screening.isCanceled {
                        Label("Séance annulée", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)
                    } else if screening.hasPassed {
                        Label(L10n.text("screening_passed", language: appLanguage), systemImage: "clock.arrow.circlepath")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    Text(Self.dayFormatter.string(from: screening.startsAt))
                        .font(.title3)
                        .foregroundStyle(screening.hasPassed ? .tertiary : .secondary)

                    LabeledContent("Coucher du soleil (indicatif)") {
                        Text(Self.timeFormatter.string(from: screening.sunsetAt))
                    }
                    .font(.body)

                    LabeledContent("Début de la projection") {
                        Text(Self.timeFormatter.string(from: screening.startsAt))
                    }
                    .font(.body)

                    if let m = screening.runtimeMinutes {
                        LabeledContent("Durée") {
                            Text("\(m) min")
                        }
                        .font(.body)
                        .foregroundStyle(m == 0 ? .secondary : .primary)
                    } else {
                        LabeledContent("Durée") {
                            Text("Variable")
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                Text(screening.synopsis)
                    .font(.body)
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Références")
                        .font(.headline)
                    if screening.externalSearchLinksEnabled {
                        Link(destination: ExternalFilmLinks.imdbSearchURL(for: screening.searchTitle)) {
                            Label("Recherche sur IMDb", systemImage: "globe")
                        }
                        Link(destination: ExternalFilmLinks.allocineSearchURL(for: screening.searchTitle)) {
                            Label("Recherche sur Allociné", systemImage: "popcorn.fill")
                        }
                        Text("Les liens ouvrent Safari avec une recherche préremplie.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Recherche sur IMDb", systemImage: "globe")
                            .foregroundStyle(.secondary)
                        Label("Recherche sur Allociné", systemImage: "popcorn.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(screening.localizedTitle(language: appLanguage))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        MovieDetailView(screening: FestivalProgramBootstrap.weeks[0].orderedScreenings[0])
    }
    .environmentObject(FestivalProgramStore.preview)
    .environmentObject(WatchListStore())
}
