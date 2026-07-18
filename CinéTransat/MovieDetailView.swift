//
//  MovieDetailView.swift
//  CinéTransat
//

import SwiftUI
import EventKit

/// Which ordered list prev/next controls move through on the detail screen.
enum MovieDetailLineupScope: Hashable {
    case fullProgram
    case watchListOnly
    case todayOnly
}

struct MovieDetailView: View {
    @EnvironmentObject private var program: FestivalProgramStore
    @EnvironmentObject private var watchList: WatchListStore
    @EnvironmentObject private var watchListStats: WatchListStatsStore
    @EnvironmentObject private var rattrapageVotes: RattrapageVotesStore
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue

    let lineupScope: MovieDetailLineupScope
    @State private var screening: Screening
    @State private var calendarEditPayload: CalendarEditPayload?
    @State private var showCalendarAccessDenied = false

    private struct CalendarEditPayload: Identifiable {
        let id = UUID()
        let store: EKEventStore
        let event: EKEvent
    }

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
        case .todayOnly:
            program.allScreenings.screeningsToday()
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

    private var showsFilmNavigation: Bool {
        lineupScope != .todayOnly
    }

    private func watchListToggleAction(for screening: Screening) -> (() -> Void)? {
        let mayAdd = program.canAddToWatchList(screening)
        guard mayAdd || watchList.contains(screening) else { return nil }
        return { watchList.toggle(screening, seasonYear: program.seasonYear, mayAdd: mayAdd) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if showsFilmNavigation {
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
                            .accessibilityLabel(L10n.text("detail_previous_film", language: appLanguage))
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
                            .accessibilityLabel(L10n.text("detail_next_film", language: appLanguage))
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .frame(minWidth: 44, minHeight: 44)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    MoviePosterCell(
                        screening: screening,
                        compact: false,
                        isOnWatchList: watchList.contains(screening),
                        watchListEnabled: program.canAddToWatchList(screening),
                        onWatchListToggle: watchListToggleAction(for: screening)
                    )
                    .frame(maxWidth: 280)
                    .frame(maxWidth: .infinity)
                }

                VStack(alignment: .leading, spacing: 8) {
                    if screening.isCanceled {
                        Label(L10n.text("detail_screening_canceled", language: appLanguage), systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)
                    } else if screening.hasPassed {
                        Label(L10n.text("screening_passed", language: appLanguage), systemImage: "clock.arrow.circlepath")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    Text(FestivalDateFormatters.screeningDay(screening.startsAt, language: appLanguage))
                        .font(.title3)
                        .foregroundStyle(screening.hasPassed ? .tertiary : .secondary)

                    if let count = watchListStats.count(screeningId: screening.id),
                       count > 0 {
                        Label(
                            L10n.watchlistInterest(count, language: appLanguage),
                            systemImage: "bookmark.fill"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    ScreeningFactsGrid(screening: screening, language: appLanguage)

                    if !screening.isRattrapageEvening {
                        ScreeningLanguageRow(screening: screening, language: appLanguage)
                    }

                    if !screening.isCanceled {
                        Button {
                            Task { await presentCalendarEditor() }
                        } label: {
                            Label(
                                L10n.text("calendar_add_one", language: appLanguage),
                                systemImage: "calendar.badge.plus"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    Text(screening.localizedSynopsis(language: appLanguage))
                        .font(.body)
                        .foregroundStyle(.primary)
                        .padding(.top, 4)
                }

                if screening.isRattrapageEvening {
                    RattrapageDetailSection(
                        canceledScreenings: program.allScreenings.canceledForRattrapage(
                            excludingRattrapageID: screening.id
                        ),
                        language: appLanguage,
                        seasonYear: program.seasonYear,
                        votingOpen: program.publicConfig.rattrapageVotingOpen,
                        votes: rattrapageVotes
                    )
                }

                if screening.externalSearchLinksEnabled || screening.releaseYear != nil {
                    HStack(alignment: .center) {
                        if screening.externalSearchLinksEnabled {
                            HStack(spacing: 20) {
                                Link(destination: ExternalFilmLinks.imdbSearchURL(for: screening.searchTitle)) {
                                    Label(L10n.text("detail_search_imdb", language: appLanguage), systemImage: "movieclapper.fill")
                                }
                                Link(destination: ExternalFilmLinks.allocineSearchURL(for: screening.searchTitle)) {
                                    Label(L10n.text("detail_search_allocine", language: appLanguage), systemImage: "popcorn.fill")
                                }
                            }
                        }

                        Spacer(minLength: 12)

                        if let year = screening.releaseYear {
                            Text(verbatim: "\(year)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .accessibilityLabel(L10n.text("detail_film_year", language: appLanguage))
                                .accessibilityValue("\(year)")
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .festivalScreenBackground()
        .navigationTitle(screening.localizedTitle(language: appLanguage))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            watchListStats.startObserving(screeningId: screening.id)
        }
        .onDisappear {
            watchListStats.stopObserving(screeningId: screening.id)
        }
        .onChange(of: screening.id) { oldId, newId in
            watchListStats.stopObserving(screeningId: oldId)
            watchListStats.startObserving(screeningId: newId)
        }
        .sheet(item: $calendarEditPayload) { payload in
            CalendarEventEditView(eventStore: payload.store, event: payload.event)
        }
        .alert(
            L10n.text("calendar_add_one", language: appLanguage),
            isPresented: $showCalendarAccessDenied
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(L10n.text("calendar_access_denied", language: appLanguage))
        }
    }

    private func presentCalendarEditor() async {
        let store = EKEventStore()
        guard await ScreeningCalendarService.requestAccess(using: store) else {
            showCalendarAccessDenied = true
            return
        }
        calendarEditPayload = CalendarEditPayload(
            store: store,
            event: ScreeningCalendarService.makeEvent(
                screening: screening,
                language: appLanguage,
                store: store
            )
        )
    }
}

// MARK: - Screening language row

private struct ScreeningLanguageRow: View {
    let screening: Screening
    let language: AppLanguage

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            languageColumn(
                symbol: "mouth.fill",
                label: L10n.text("detail_audio_language", language: language),
                value: screening.localizedAudioLanguage(language: language)
                    ?? L10n.text("detail_language_unspecified", language: language)
            )
            languageColumn(
                symbol: "captions.bubble",
                label: L10n.text("detail_subtitles", language: language),
                value: screening.localizedSubtitleLanguage(language: language)
                    ?? L10n.text("detail_language_unspecified", language: language)
            )
        }
        .padding(.vertical, 4)
    }

    private func languageColumn(symbol: String, label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(height: 20)

            Text(value)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }
}

// MARK: - Screening facts grid

private struct ScreeningFactsGrid: View {
    let screening: Screening
    let language: AppLanguage

    private struct Column: Identifiable {
        let id: Int
        let symbol: String
        let label: String
        let value: String
        let muted: Bool
    }

    private var columns: [Column] {
        let durationValue: String
        let durationMuted: Bool
        if let minutes = screening.runtimeMinutes {
            durationValue = minutes == 0 ? "—" : "\(minutes) min"
            durationMuted = minutes == 0
        } else {
            durationValue = L10n.text("detail_duration_variable", language: language)
            durationMuted = true
        }

        return [
            Column(
                id: 0,
                symbol: "sunset.fill",
                label: L10n.text("detail_sunset", language: language),
                value: FestivalDateFormatters.screeningTime(screening.sunsetAt, language: language),
                muted: false
            ),
            Column(
                id: 1,
                symbol: "popcorn",
                label: L10n.text("detail_start", language: language),
                value: FestivalDateFormatters.screeningTime(screening.startsAt, language: language),
                muted: screening.hasPassed
            ),
            Column(
                id: 2,
                symbol: "hourglass",
                label: L10n.text("detail_duration", language: language),
                value: durationValue,
                muted: durationMuted
            ),
            Column(
                id: 3,
                symbol: "hand.raised.fill",
                label: L10n.text("detail_legal_age", language: language),
                value: screening.legalAge.map { "\($0)+" } ?? "—",
                muted: screening.legalAge == nil
            ),
            Column(
                id: 4,
                symbol: "figure.and.child.holdinghands",
                label: L10n.text("detail_recommended_age", language: language),
                value: screening.recommendedAge.map { "\($0)+" } ?? "—",
                muted: screening.recommendedAge == nil
            ),
        ]
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(columns) { column in
                VStack(spacing: 6) {
                    Image(systemName: column.symbol)
                        .font(.subheadline.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .frame(height: 20)

                    Text(column.value)
                        .font(.caption.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(column.muted ? .secondary : .primary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(column.label), \(column.value)")
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Soirée Rattrapage

private struct RattrapageDetailSection: View {
    let canceledScreenings: [Screening]
    let language: AppLanguage
    let seasonYear: Int
    let votingOpen: Bool
    @ObservedObject var votes: RattrapageVotesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if canceledScreenings.isEmpty {
                Text(L10n.text("rattrapage_none_canceled", language: language))
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else if votingOpen {
                Text(L10n.text("rattrapage_canceled_heading", language: language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(canceledScreenings) { canceled in
                        RattrapagePollOptionRow(
                            screening: canceled,
                            language: language,
                            voted: votes.hasVoted(screeningId: canceled.id),
                            voteCount: votes.voteCount(screeningId: canceled.id),
                            share: votes.voteShare(screeningId: canceled.id),
                            onToggleVote: {
                                votes.toggleVote(screeningId: canceled.id, seasonYear: seasonYear)
                            }
                        )
                    }
                }

                if votes.totalVoteCount > 0 {
                    Text(L10n.rattrapageTotalVotes(votes.totalVoteCount, language: language))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            } else {
                Text(L10n.text("rattrapage_canceled_heading", language: language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(canceledScreenings) { canceled in
                        NavigationLink(value: canceled) {
                            Text(canceled.localizedTitle(language: language))
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(L10n.text("rattrapage_voting_closed", language: language))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .onAppear {
            guard votingOpen else { return }
            votes.startObserving(
                screeningIds: canceledScreenings.map(\.id),
                seasonYear: seasonYear
            )
        }
        .onChange(of: votingOpen) { _, open in
            if open {
                votes.startObserving(
                    screeningIds: canceledScreenings.map(\.id),
                    seasonYear: seasonYear
                )
            } else {
                votes.stopAllObservations()
            }
        }
        .onChange(of: canceledScreenings.map(\.id)) { _, ids in
            guard votingOpen else { return }
            votes.startObserving(screeningIds: ids, seasonYear: seasonYear)
        }
    }
}

/// WhatsApp-style poll option: checkbox + title + vote count over an animated fill bar.
private struct RattrapagePollOptionRow: View {
    let screening: Screening
    let language: AppLanguage
    let voted: Bool
    let voteCount: Int
    let share: Double
    let onToggleVote: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Button(action: onToggleVote) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: voted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(voted ? Color.festivalAccent : Color.secondary)

                    Text(screening.localizedTitle(language: language))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(verbatim: "\(voteCount)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(voted ? Color.festivalAccent : Color.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .background {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.primary.opacity(0.06))

                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    voted
                                        ? Color.festivalAccent.opacity(0.38)
                                        : Color.festivalAccent.opacity(0.18)
                                )
                                .frame(width: max(0, geo.size.width * share))
                                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: share)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                voted
                    ? L10n.text("rattrapage_vote_remove", language: language)
                    : L10n.text("rattrapage_vote_add", language: language)
            )
            .accessibilityValue("\(screening.localizedTitle(language: language)), \(voteCount)")

            NavigationLink(value: screening) {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(minWidth: 36, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(screening.localizedTitle(language: language))
        }
    }
}

#Preview("Movie detail — facts row") {
    let stats = WatchListStatsStore()
    NavigationStack {
        MovieDetailView(screening: FestivalProgramBootstrap.weeks[0].orderedScreenings[0])
    }
    .environmentObject(FestivalProgramStore.preview)
    .environmentObject(WatchListStore.preview(statsStore: stats))
    .environmentObject(stats)
    .environmentObject(RattrapageVotesStore())
}
