//
//  ProgramViews.swift
//  CinéTransat
//

import SwiftUI

// MARK: - Week pager (below posters, high contrast)

private struct WeekPageIndicatorBar: View {
    let count: Int
    @Binding var selection: Int
    var language: AppLanguage

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0 ..< count, id: \.self) { index in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = index
                    }
                } label: {
                    Capsule()
                        .fill(index == selection ? Color.festivalAccent : Color.festivalProgramTitle.opacity(0.22))
                        .frame(width: index == selection ? 28 : 10, height: 10)
                        .frame(minWidth: 36, minHeight: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    String(format: L10n.text("program_week_accessibility", language: language), index + 1)
                )
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background {
            Capsule()
                .fill(Color.festivalProgramPagerTrack)
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                }
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

private struct ProgramWeekHeaderCapsule: View {
    let weekNumber: Int
    let weekLabel: String
    let language: AppLanguage
    var compact: Bool = true

    var body: some View {
        Text(localizedWeekLabel(number: weekNumber, weekLabel: weekLabel, language: language))
            .font(.caption.weight(.bold))
            .tracking(0.6)
            .foregroundStyle(Color.festivalAccent)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 14)
            .padding(.vertical, compact ? 5 : 7)
            .background {
                Capsule()
                    .fill(Color.festivalAccent.opacity(0.14))
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.festivalAccent.opacity(0.35), lineWidth: 1)
                    }
            }
    }
}

// MARK: - Week grid (fits without vertical scroll)

private struct WeekProgramFitContent: View {
    @EnvironmentObject private var program: FestivalProgramStore
    @EnvironmentObject private var watchList: WatchListStore
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue
    @State private var justToggledWatchListID: String?
    @Binding var path: NavigationPath
    let week: FestivalWeek
    let weekNumber: Int
    var compact: Bool
    /// Pulls the date chip closer to the navigation bar (iPhone).
    var tightTop: Bool = false
    /// When false, the week capsule is shown in the parent toolbar row instead.
    var showWeekHeader: Bool = true

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fr
    }

    private var rows: [[Screening]] {
        let o = week.orderedScreenings
        return [Array(o.prefix(2)), Array(o.dropFirst(2).prefix(2))]
    }

    var body: some View {
        GeometryReader { geo in
            let hPad: CGFloat = compact ? 10 : 20
            let weekStripH: CGFloat = showWeekHeader ? (compact ? 30 : 38) : 0
            let dateToGridGap: CGFloat = showWeekHeader ? (compact ? 8 : 12) : (compact ? 4 : 8)
            let rowGap: CGFloat = compact ? 2 : 6
            let colGap: CGFloat = compact ? 14 : 18
            // Reserve enough space for two full caption lines to avoid clipping.
            let titleBlock: CGFloat = compact ? 38 : 44

            let topInset: CGFloat = tightTop ? -2 : (compact ? 2 : 6)
            let innerW = geo.size.width - hPad * 2
            let innerH = max(
                0,
                geo.size.height - topInset - weekStripH - dateToGridGap
            )

            let posterWFromWidth = (innerW - colGap) / 2
            let posterWFromHeight = (innerH - rowGap - titleBlock * 2) / 3
            // Slightly under-size so the week pager stays fully visible above the tab bar.
            let posterScale: CGFloat = compact ? 0.90 : 0.94
            let posterW = max(68, min(posterWFromWidth, posterWFromHeight) * posterScale)

            VStack(spacing: 0) {
                if showWeekHeader {
                    HStack(alignment: .center, spacing: 8) {
                        ProgramWeekHeaderCapsule(
                            weekNumber: weekNumber,
                            weekLabel: week.label,
                            language: appLanguage,
                            compact: compact
                        )

                        Spacer(minLength: 0)
                    }
                    .frame(height: weekStripH)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Color.clear.frame(height: dateToGridGap)
                } else {
                    Color.clear.frame(height: dateToGridGap)
                }

                VStack(spacing: rowGap) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .top, spacing: colGap) {
                            ForEach(row) { screening in
                                posterCell(screening: screening, posterW: posterW, titleBlock: titleBlock)
                                    .frame(width: posterW, alignment: .top)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, hPad)
            .padding(.top, topInset)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
    }

    private func watchListToggleAction(for screening: Screening) -> (() -> Void)? {
        guard program.canModifyWatchList(screening) else { return nil }
        let mayAdd = program.canAddToWatchList(screening)
        return {
            justToggledWatchListID = screening.watchListID
            watchList.toggle(screening, seasonYear: program.seasonYear, mayAdd: mayAdd)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if justToggledWatchListID == screening.watchListID {
                    justToggledWatchListID = nil
                }
            }
        }
    }

    @ViewBuilder
    private func posterCell(screening: Screening, posterW: CGFloat, titleBlock: CGFloat) -> some View {
        VStack(spacing: compact ? 4 : 6) {
            MoviePosterCell(
                screening: screening,
                compact: compact,
                posterWidth: posterW,
                isOnWatchList: watchList.contains(screening),
                watchListEnabled: program.canAddToWatchList(screening),
                onWatchListToggle: watchListToggleAction(for: screening)
            )
            Text(screening.localizedTitle(language: appLanguage))
                .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                .foregroundStyle(
                    screening.hasPassed ? Color.festivalAccent.opacity(0.55) : Color.festivalAccent
                )
                .opacity(screening.hasPassed ? 0.8 : 1)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: posterW - (compact ? 8 : 12), alignment: .center)
                .frame(width: posterW, height: titleBlock, alignment: .top)
        }
        .frame(width: posterW, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture {
            if justToggledWatchListID == screening.watchListID {
                justToggledWatchListID = nil
                return
            }
            path.append(screening)
        }
    }
}

// MARK: - Phone

struct ProgramPhoneView: View {
    @EnvironmentObject private var program: FestivalProgramStore
    @EnvironmentObject private var programNav: ProgramNavigationModel
    @Environment(\.appStoreScreenshotProgramWeekIndex) private var screenshotWeekIndex
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue
    var programFocusGeneration: Int = 0

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fr
    }

    private let horizontalPadding: CGFloat = 10

    var body: some View {
        NavigationStack(path: $programNav.path) {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 8) {
                    ProgramSeasonPicker(appLanguage: appLanguage) {
                        syncToFocusedWeek(animated: false)
                    }

                    Spacer(minLength: 8)

                    if program.weeks.indices.contains(programNav.weekIndex) {
                        ProgramWeekHeaderCapsule(
                            weekNumber: programNav.weekIndex + 1,
                            weekLabel: program.weeks[programNav.weekIndex].label,
                            language: appLanguage,
                            compact: true
                        )
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 4)
                .padding(.bottom, 6)

                TabView(selection: $programNav.weekIndex) {
                    ForEach(Array(program.weeks.enumerated()), id: \.element.id) { index, week in
                        WeekProgramFitContent(
                            path: $programNav.path,
                            week: week,
                            weekNumber: index + 1,
                            compact: true,
                            tightTop: true,
                            showWeekHeader: false
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                WeekPageIndicatorBar(
                    count: program.weeks.count,
                    selection: $programNav.weekIndex,
                    language: appLanguage
                )
                .fixedSize(horizontal: false, vertical: true)
            }
            .festivalScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Screening.self) { screening in
                MovieDetailView(screening: screening, lineupScope: .fullProgram) { id in
                    programNav.displayedDetailScreeningID = id
                }
            }
            .onAppear {
                if let screenshotWeekIndex {
                    let maxIndex = max(0, program.weeks.count - 1)
                    programNav.weekIndex = min(max(0, screenshotWeekIndex), maxIndex)
                } else {
                    syncToFocusedWeek(animated: false)
                }
                programNav.applyPendingOpenIfNeeded()
            }
            .onChange(of: programFocusGeneration) { _, _ in
                syncToFocusedWeek(animated: true)
            }
            .onChange(of: programNav.openToken) { _, _ in
                syncToFocusedWeek(animated: false)
                programNav.applyPendingOpenIfNeeded()
            }
            .onChange(of: program.lastUpdatedAt) { _, _ in
                // After Firestore loads, correct the default Week 1 if we should be further ahead.
                guard programNav.weekIndex == 0, focusedWeekIndex != 0 else { return }
                syncToFocusedWeek(animated: false)
            }
            .onChange(of: program.seasonYear) { _, _ in
                syncToFocusedWeek(animated: false)
            }
        }
    }

    private var focusedWeekIndex: Int {
        guard !program.weeks.isEmpty else { return 0 }
        return program.weeks.indexOfWeek(for: Date())
    }

    private func syncToFocusedWeek(animated: Bool) {
        guard !program.weeks.isEmpty else { return }
        let target = focusedWeekIndex
        guard programNav.weekIndex != target else { return }
        if animated {
            withAnimation(.easeInOut(duration: 0.2)) {
                programNav.weekIndex = target
            }
        } else {
            programNav.weekIndex = target
        }
    }
}

// MARK: - iPad

struct ProgramPadView: View {
    @EnvironmentObject private var program: FestivalProgramStore
    @EnvironmentObject private var programNav: ProgramNavigationModel
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue
    var programFocusGeneration: Int = 0

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fr
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $programNav.selectedWeek) {
                ForEach(program.weeks) { week in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(week.label)
                            .font(.headline)
                            .foregroundStyle(Color.festivalProgramTitle)
                        Text(subtitle(for: week))
                            .font(.caption)
                            .foregroundStyle(Color.festivalProgramTitleMuted)
                    }
                    .tag(week)
                }
            }
            .festivalListChrome()
            .festivalScreenBackground()
            .navigationTitle(L10n.text("program_weeks_title", language: appLanguage))
            .onAppear {
                syncToFocusedWeek()
                programNav.applyPendingOpenIfNeeded()
            }
            .onChange(of: program.weeks) { _, weeks in
                if let selected = programNav.selectedWeek,
                   weeks.contains(where: { $0.id == selected.id }) {
                    return
                }
                syncToFocusedWeek()
            }
            .onChange(of: programNav.openToken) { _, _ in
                syncToFocusedWeek()
                programNav.applyPendingOpenIfNeeded()
            }
        } detail: {
            NavigationStack(path: $programNav.path) {
                Group {
                    if let week = programNav.selectedWeek ?? program.weeks.first {
                        VStack(spacing: 0) {
                            HStack(alignment: .center, spacing: 8) {
                                ProgramSeasonPicker(appLanguage: appLanguage) {
                                    syncToFocusedWeek()
                                }

                                Spacer(minLength: 8)

                                ProgramWeekHeaderCapsule(
                                    weekNumber: weekNumber(for: week),
                                    weekLabel: week.label,
                                    language: appLanguage,
                                    compact: false
                                )
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 8)

                            WeekProgramFitContent(
                                path: $programNav.path,
                                week: week,
                                weekNumber: weekNumber(for: week),
                                compact: false,
                                tightTop: false,
                                showWeekHeader: false
                            )
                        }
                            .festivalScreenBackground()
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar(.hidden, for: .navigationBar)
                            .navigationDestination(for: Screening.self) { screening in
                                MovieDetailView(screening: screening, lineupScope: .fullProgram) { id in
                                    programNav.displayedDetailScreeningID = id
                                }
                            }
                    } else {
                        ContentUnavailableView(
                            L10n.text("program_pick_week_title", language: appLanguage),
                            systemImage: "calendar",
                            description: Text(L10n.text("program_pick_week_body", language: appLanguage))
                        )
                        .festivalScreenBackground()
                    }
                }
            }
            .festivalScreenBackground()
        }
        .background(Color.festivalProgramBackground)
        .onChange(of: programFocusGeneration) { _, _ in
            syncToFocusedWeek()
        }
        .onChange(of: program.lastUpdatedAt) { _, _ in
            guard let first = program.weeks.first,
                  programNav.selectedWeek?.id == first.id,
                  let focused = focusedWeek,
                  focused.id != first.id else { return }
            syncToFocusedWeek()
        }
        .onChange(of: program.seasonYear) { _, _ in
            syncToFocusedWeek()
        }
    }

    private var focusedWeek: FestivalWeek? {
        guard !program.weeks.isEmpty else { return nil }
        return program.weeks[program.weeks.indexOfWeek(for: Date())]
    }

    private func syncToFocusedWeek() {
        guard let week = focusedWeek else { return }
        guard programNav.selectedWeek?.id != week.id else { return }
        programNav.selectedWeek = week
    }

    private func subtitle(for week: FestivalWeek) -> String {
        let titles = week.orderedScreenings.map { $0.localizedTitle(language: appLanguage) }.joined(separator: ", ")
        if titles.count > 72 {
            return String(titles.prefix(70)) + "…"
        }
        return titles
    }

    private func weekNumber(for week: FestivalWeek) -> Int {
        (program.weeks.firstIndex { $0.id == week.id } ?? 0) + 1
    }
}

struct ProgramRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    var programFocusGeneration: Int = 0

    /// `horizontalSizeClass` can be `nil` for the first layout pass; treating that as non-regular
    /// avoids showing `NavigationSplitView` iPad chrome on iPhone (often reads as a blank screen).
    private var usePadProgramLayout: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        if usePadProgramLayout {
            ProgramPadView(programFocusGeneration: programFocusGeneration)
        } else {
            ProgramPhoneView(programFocusGeneration: programFocusGeneration)
        }
    }
}
