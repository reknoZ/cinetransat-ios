//
//  ProgramViews.swift
//  CinéTransat
//

import SwiftUI

// MARK: - Week pager (below posters, high contrast)

private struct WeekPageIndicatorBar: View {
    let count: Int
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 9) {
            ForEach(0 ..< count, id: \.self) { index in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = index
                    }
                } label: {
                    Capsule()
                        .fill(index == selection ? Color.accentColor : Color.primary.opacity(0.22))
                        .frame(width: index == selection ? 22 : 7, height: 7)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Semaine \(index + 1)")
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 18)
        .background {
            Capsule()
                .fill(Color(red: 0.86, green: 0.87, blue: 0.89))
                .overlay {
                    Capsule()
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                }
        }
        .padding(.top, 6)
        .padding(.bottom, 4)
    }
}

// MARK: - Week grid (fits without vertical scroll)

private struct WeekProgramFitContent: View {
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
                Text(localizedWeekLabel(number: weekNumber, weekLabel: week.label, language: appLanguage))
                    .font(.caption.weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, compact ? 5 : 7)
                    .background {
                        Capsule()
                            .fill(.background.secondary)
                            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                    }
                    .frame(height: weekStripH)
                    .frame(maxWidth: .infinity)

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

    @ViewBuilder
    private func posterCell(screening: Screening, posterW: CGFloat, titleBlock: CGFloat) -> some View {
        VStack(spacing: compact ? 4 : 6) {
            MoviePosterCell(
                screening: screening,
                compact: compact,
                posterWidth: posterW,
                isOnWatchList: watchList.contains(screening),
                onWatchListToggle: {
                    justToggledWatchListID = screening.watchListID
                    watchList.toggle(screening)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if justToggledWatchListID == screening.watchListID {
                            justToggledWatchListID = nil
                        }
                    }
                }
            )
            Text(screening.localizedTitle(language: appLanguage))
                .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
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
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue
    @State private var weekIndex = 0
    @State private var path = NavigationPath()

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fr
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                TabView(selection: $weekIndex) {
                    ForEach(Array(FestivalProgramData.weeks.enumerated()), id: \.element.id) { index, week in
                        WeekProgramFitContent(path: $path, week: week, weekNumber: index + 1, compact: true, tightTop: true)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                WeekPageIndicatorBar(count: FestivalProgramData.weeks.count, selection: $weekIndex)
            }
            .background(Color.festivalProgramBackground)
            .navigationTitle(localizedProgramTitle(year: FestivalProgramData.demoYear, language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Screening.self) { screening in
                MovieDetailView(screening: screening, lineupScope: .fullProgram)
            }
        }
    }
}

// MARK: - iPad

struct ProgramPadView: View {
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue
    @State private var selectedWeek: FestivalWeek? = FestivalProgramData.weeks.first
    @State private var path = NavigationPath()

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fr
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedWeek) {
                ForEach(FestivalProgramData.weeks) { week in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(week.label)
                            .font(.headline)
                        Text(subtitle(for: week))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(week)
                }
            }
            .navigationTitle("Semaines")
        } detail: {
            NavigationStack(path: $path) {
                Group {
                    if let week = selectedWeek ?? FestivalProgramData.weeks.first {
                        WeekProgramFitContent(path: $path, week: week, weekNumber: weekNumber(for: week), compact: false, tightTop: false)
                            .background(Color.festivalProgramBackground)
                            .navigationTitle(localizedProgramTitle(year: FestivalProgramData.demoYear, language: appLanguage))
                            .navigationBarTitleDisplayMode(.inline)
                            .navigationDestination(for: Screening.self) { screening in
                                MovieDetailView(screening: screening, lineupScope: .fullProgram)
                            }
                    } else {
                        ContentUnavailableView(
                            "Choisir une semaine",
                            systemImage: "calendar",
                            description: Text("Sélectionnez une ligne dans la colonne de gauche.")
                        )
                    }
                }
            }
        }
    }

    private func subtitle(for week: FestivalWeek) -> String {
        let titles = week.orderedScreenings.map { $0.localizedTitle(language: appLanguage) }.joined(separator: ", ")
        if titles.count > 72 {
            return String(titles.prefix(70)) + "…"
        }
        return titles
    }

    private func weekNumber(for week: FestivalWeek) -> Int {
        (FestivalProgramData.weeks.firstIndex { $0.id == week.id } ?? 0) + 1
    }
}

struct ProgramRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// `horizontalSizeClass` can be `nil` for the first layout pass; treating that as non-regular
    /// avoids showing `NavigationSplitView` iPad chrome on iPhone (often reads as a blank screen).
    private var usePadProgramLayout: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        if usePadProgramLayout {
            ProgramPadView()
        } else {
            ProgramPhoneView()
        }
    }
}
