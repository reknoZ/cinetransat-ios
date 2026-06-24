//
//  UsefulInfoView.swift
//  CinéTransat
//

import SwiftUI

struct UsefulInfoView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fr
    }

    private var sections: [PracticalInfoSection] {
        PracticalInfoSection.all(language: appLanguage, seasonYear: FestivalPublicConfig.currentSeasonYear)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(sections) { section in
                        DisclosureGroup {
                            Text(section.body)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 6)
                        } label: {
                            Label(section.title, systemImage: section.icon)
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(horizontalSizeClass == .compact ? 16 : 32)
                .padding(.vertical, 8)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(L10n.text("info_nav_title", language: appLanguage))
        }
    }
}

// MARK: - Sections (aligned with https://www.cinetransat.ch/infos-pratiques )

private struct PracticalInfoSection: Identifiable {
    let id: String
    let title: String
    let icon: String
    let body: String

    static func all(language: AppLanguage, seasonYear: Int) -> [PracticalInfoSection] {
        let year = String(seasonYear)
        return [
            section("free", icon: "gift.fill", language: language),
            section("schedule", icon: "calendar", language: language, bodyFormatArgument: year),
            section("age", icon: "person.crop.circle.badge.questionmark", language: language),
            section("languages", icon: "captions.bubble.fill", language: language),
            section("bar", icon: "cup.and.saucer.fill", language: language),
            section("deckchairs", icon: "chair.lounge.fill", language: language),
            section("transport", icon: "tram.fill", language: language),
            section("cancellations", icon: "cloud.bolt.rain.fill", language: language),
            section("toilets", icon: "toilet.fill", language: language),
            section("smoking", icon: "smoke.fill", language: language),
            section("waste", icon: "trash.fill", language: language),
            section("dogs", icon: "pawprint.fill", language: language),
            section("bikes", icon: "bicycle", language: language),
            section("accessibility", icon: "figure.roll", language: language),
        ]
    }

    private static func section(
        _ key: String,
        icon: String,
        language: AppLanguage,
        bodyFormatArgument: String? = nil
    ) -> PracticalInfoSection {
        let bodyKey = "info_\(key)_body"
        let rawBody = L10n.text(bodyKey, language: language).trimmingCharacters(in: .whitespacesAndNewlines)
        let body = bodyFormatArgument.map { String(format: rawBody, $0) } ?? rawBody
        return PracticalInfoSection(
            id: key,
            title: L10n.text("info_\(key)_title", language: language),
            icon: icon,
            body: body
        )
    }
}

#Preview {
    UsefulInfoView()
}
