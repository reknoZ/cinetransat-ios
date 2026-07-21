//
//  ProgramSeasonToolbar.swift
//  CinéTransat
//

import SwiftUI

/// Current season year with chevrons to move between available seasons (newest ↔ oldest).
struct ProgramSeasonPicker: View {
    @EnvironmentObject private var program: FestivalProgramStore
    let appLanguage: AppLanguage
    var onSeasonChange: (() -> Void)? = nil

    private var years: [Int] {
        program.availableSeasonYears
    }

    private var currentIndex: Int? {
        years.firstIndex(of: program.seasonYear)
    }

    /// Older season (e.g. 2025 when viewing 2026).
    private var olderYear: Int? {
        guard let i = currentIndex, i + 1 < years.count else { return nil }
        return years[i + 1]
    }

    /// Newer season (e.g. 2026 when viewing 2025).
    private var newerYear: Int? {
        guard let i = currentIndex, i > 0 else { return nil }
        return years[i - 1]
    }

    private var showsChevrons: Bool {
        years.count > 1
    }

    var body: some View {
        HStack(spacing: 2) {
            if showsChevrons {
                seasonChevron(
                    systemName: "chevron.left",
                    enabled: olderYear != nil,
                    label: L10n.text("program_season_older", language: appLanguage)
                ) {
                    if let year = olderYear {
                        select(year)
                    }
                }
            }

            Text(verbatim: "\(program.seasonYear)")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.festivalAccent)
                .frame(minWidth: 64)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel(seasonAccessibilityLabel(year: program.seasonYear))

            if showsChevrons {
                seasonChevron(
                    systemName: "chevron.right",
                    enabled: newerYear != nil,
                    label: L10n.text("program_season_newer", language: appLanguage)
                ) {
                    if let year = newerYear {
                        select(year)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.text("program_season_picker", language: appLanguage))
    }

    private func seasonChevron(
        systemName: String,
        enabled: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.festivalAccent.opacity(enabled ? 1 : 0.28))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func select(_ year: Int) {
        program.selectSeason(year: year)
        onSeasonChange?()
    }

    private func seasonAccessibilityLabel(year: Int) -> String {
        switch appLanguage {
        case .fr:
            return "Saison \(year)"
        case .en:
            return "Season \(year)"
        }
    }
}
