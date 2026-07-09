//
//  ProgramSeasonToolbar.swift
//  CinéTransat
//

import SwiftUI

/// Horizontal season chips (newest first), left-aligned.
struct ProgramSeasonPicker: View {
    @EnvironmentObject private var program: FestivalProgramStore
    let appLanguage: AppLanguage
    var onSeasonChange: (() -> Void)? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(program.availableSeasonYears, id: \.self) { year in
                    seasonChip(year: year)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.text("program_season_picker", language: appLanguage))
    }

    private func seasonChip(year: Int) -> some View {
        let selected = year == program.seasonYear
        return Button {
            program.selectSeason(year: year)
            onSeasonChange?()
        } label: {
            Text(verbatim: "\(year)")
                .font(.system(.subheadline, design: .rounded).weight(selected ? .bold : .semibold))
                .monospacedDigit()
                .foregroundStyle(selected ? Color.festivalAccent : Color.festivalProgramTitle.opacity(0.65))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background {
                    if selected {
                        Capsule()
                            .fill(Color.festivalAccent.opacity(0.14))
                            .overlay {
                                Capsule()
                                    .strokeBorder(Color.festivalAccent.opacity(0.35), lineWidth: 1)
                            }
                    } else {
                        Capsule()
                            .fill(Color.festivalProgramTitle.opacity(0.08))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(seasonAccessibilityLabel(year: year))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func seasonAccessibilityLabel(year: Int) -> String {
        switch appLanguage {
        case .fr:
            return year == program.seasonYear ? "Saison \(year), sélectionnée" : "Saison \(year)"
        case .en:
            return year == program.seasonYear ? "Season \(year), selected" : "Season \(year)"
        }
    }
}
