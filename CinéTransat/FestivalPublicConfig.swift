//
//  FestivalPublicConfig.swift
//  CinéTransat
//

import Foundation

struct FestivalPublicConfig: Equatable {
    let currentSeasonYear: Int
    let websiteURL: URL
    let practicalInfoURL: URL
    let contactEmail: String
    let facebookURL: URL?
    let instagramURL: URL?
    /// URL template for posters. Use `{id}` (screening day `yyyyMMdd`) and optionally `{year}`.
    let posterBaseURL: String?
    /// When true, Soirée Rattrapage shows the interactive vote UI (CT Admin toggle).
    let rattrapageVotingOpen: Bool

    /// Active festival season (splash, defaults before Firestore loads).
    static let currentSeasonYear = 2026

    static let defaults = FestivalPublicConfig(
        currentSeasonYear: currentSeasonYear,
        websiteURL: URL(string: "https://www.cinetransat.ch/")!,
        practicalInfoURL: URL(string: "https://www.cinetransat.ch/infos-pratiques")!,
        contactEmail: "info@cinetransat.ch",
        facebookURL: URL(string: "https://www.facebook.com/cinetransat"),
        instagramURL: URL(string: "https://www.instagram.com/cinetransat"),
        posterBaseURL: "https://cinetransat-497ce.web.app/posters/{posterKey}.jpg",
        rattrapageVotingOpen: false
    )
}

struct FestivalPublicConfigDocument: Codable {
    let schemaVersion: Int
    let currentSeasonYear: Int?
    let seasonYear: Int?
    let websiteURL: String?
    let practicalInfoURL: String?
    let contactEmail: String?
    let facebookURL: String?
    let instagramURL: String?
    let posterBaseURL: String?
    let rattrapageVotingOpen: Bool?
}

extension FestivalPublicConfig {
    static func decode(from document: FestivalPublicConfigDocument) throws -> FestivalPublicConfig {
        func url(_ string: String?, fallback: URL) throws -> URL {
            guard let string, let value = URL(string: string) else { return fallback }
            return value
        }

        let year = document.currentSeasonYear ?? document.seasonYear ?? Self.currentSeasonYear

        return FestivalPublicConfig(
            currentSeasonYear: year,
            websiteURL: try url(document.websiteURL, fallback: defaults.websiteURL),
            practicalInfoURL: try url(document.practicalInfoURL, fallback: defaults.practicalInfoURL),
            contactEmail: document.contactEmail ?? defaults.contactEmail,
            facebookURL: document.facebookURL.flatMap(URL.init(string:)),
            instagramURL: document.instagramURL.flatMap(URL.init(string:)),
            posterBaseURL: document.posterBaseURL,
            rattrapageVotingOpen: document.rattrapageVotingOpen ?? false
        )
    }
}
