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
        HStack(spacing: 9) {
            ForEach(0 ..< count, id: \.self) { index in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = index
                    }
                } label: {
                    Capsule()
                        .fill(index == selection ? Color.festivalAccent : Color.festivalProgramTitle.opacity(0.22))
                        .frame(width: index == selection ? 22 : 7, height: 7)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    String(format: L10n.text("program_week_accessibility", language: language), index + 1)
                )
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 18)
        .background {
            Capsule()
                .fill(Color.festivalProgramPagerTrack)
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                }
        }
        .padding(.top, 6)
        .padding(.bottom, 4)
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
            let weekStripH: CGFloat = compact ? 30 : 38
            let dateToGridGap: CGFloat = compact ? 8 : 12
            let rowGap: CGFloat = compact ? 6 : 10
            let colGap: CGFloat = compact ? 14 : 18
            // Reserve enough space for two full caption lines to avoid clipping.
            let titleBlock: CGFloat = compact ? 42 : 46

            let topInset: CGFloat = tightTop ? -2 : (compact ? 2 : 6)
            let innerW = geo.size.width - hPad * 2
            let innerH = max(
                0,
                geo.size.height - topInset - weekStripH - dateToGridGap
            )

            let posterWFromWidth = (innerW - colGap) / 2
            let posterWFromHeight = (innerH - rowGap - titleBlock * 2) / 3
            let posterW = max(72, min(posterWFromWidth, posterWFromHeight))

            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 8) {
                    Text(localizedWeekLabel(number: weekNumber, weekLabel: week.label, language: appLanguage))
                        .font(.caption.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(Color.festivalAccent)
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

                    Spacer(minLength: 0)
                }
                .frame(height: weekStripH)
                .frame(maxWidth: .infinity, alignment: .leading)

                Color.clear.frame(height: dateToGridGap)

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
        let mayAdd = program.canAddToWatchList(screening)
        guard mayAdd || watchList.contains(screening) else { return nil }
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
    @Environment(\.appStoreScreenshotProgramWeekIndex) private var screenshotWeekIndex
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue
    @State private var weekIndex = 0
    @State private var path = NavigationPath()
    var programFocusGeneration: Int = 0

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fr
    }

    private let horizontalPadding: CGFloat = 10

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                ProgramSeasonPicker(appLanguage: appLanguage) {
                    weekIndex = 0
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 4)
                .padding(.bottom, 2)

                TabView(selection: $weekIndex) {
                    ForEach(Array(program.weeks.enumerated()), id: \.element.id) { index, week in
                        WeekProgramFitContent(path: $path, week: week, weekNumber: index + 1, compact: true, tightTop: true)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                WeekPageIndicatorBar(count: program.weeks.count, selection: $weekIndex, language: appLanguage)
            }
            .festivalScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Screening.self) { screening in
                MovieDetailView(screening: screening, lineupScope: .fullProgram)
            }
            .onAppear {
                guard let screenshotWeekIndex else { return }
                let maxIndex = max(0, program.weeks.count - 1)
                weekIndex = min(max(0, screenshotWeekIndex), maxIndex)
            }
            .onChange(of: programFocusGeneration) { _, generation in
                advanceToCurrentWeek(generation: generation)
            }
            .onChange(of: program.weeks.count) { _, _ in
                advanceToCurrentWeek(generation: programFocusGeneration)
            }
        }
    }

    private func advanceToCurrentWeek(generation: Int) {
        guard generation > 0, !program.weeks.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            weekIndex = program.weeks.indexOfWeek(for: Date())
        }
    }
}

// MARK: - iPad

struct ProgramPadView: View {
    @EnvironmentObject private var program: FestivalProgramStore
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue
    @State private var selectedWeek: FestivalWeek?
    @State private var path = NavigationPath()
    var programFocusGeneration: Int = 0

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fr
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedWeek) {
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
                if selectedWeek == nil {
                    selectedWeek = program.weeks.first
                }
            }
            .onChange(of: program.weeks) { _, weeks in
                if let selected = selectedWeek, weeks.contains(where: { $0.id == selected.id }) {
                    return
                }
                selectedWeek = weeks.first
            }
        } detail: {
            NavigationStack(path: $path) {
                Group {
                    if let week = selectedWeek ?? program.weeks.first {
                        VStack(spacing: 0) {
                            ProgramSeasonPicker(appLanguage: appLanguage) {
                                selectedWeek = program.weeks.first
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 4)

                            WeekProgramFitContent(path: $path, week: week, weekNumber: weekNumber(for: week), compact: false, tightTop: false)
                        }
                            .festivalScreenBackground()
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar(.hidden, for: .navigationBar)
                            .navigationDestination(for: Screening.self) { screening in
                                MovieDetailView(screening: screening, lineupScope: .fullProgram)
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
        .onChange(of: programFocusGeneration) { _, generation in
            advanceToCurrentWeek(generation: generation)
        }
        .onChange(of: program.weeks.count) { _, _ in
            advanceToCurrentWeek(generation: programFocusGeneration)
        }
    }

    private func advanceToCurrentWeek(generation: Int) {
        guard generation > 0, !program.weeks.isEmpty else { return }
        selectedWeek = program.weeks[program.weeks.indexOfWeek(for: Date())]
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
