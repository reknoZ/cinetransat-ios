//
//  FestivalProgramFeed.swift
//  CinéTransat
//

import Foundation

struct FestivalProgramDocument: Codable {
    let schemaVersion: Int
    let seasonYear: Int
    let updatedAt: String?
    let weeks: [FestivalWeekDocument]
}

struct FestivalWeekDocument: Codable {
    let id: String
    let label: String
    let screenings: [ScreeningDocument]
}

struct ScreeningDocument: Codable {
    let id: String
    let title: String
    let startsAt: String
    let sunset: String
    let isCanceled: Bool
    let synopsis: String
    let synopsisEn: String?
    let runtimeMinutes: Int?
    let legalAge: Int?
    let recommendedAge: Int?
    let searchTitle: String?
    let posterURL: String?
    let posterKey: String?
    /// Legacy date-based asset names (decode only).
	var posterAssetName: String? = nil
}

enum FestivalProgramFeedDecoder {
    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601NoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func decodeProgram(from data: Data) throws -> (seasonYear: Int, weeks: [FestivalWeek]) {
        let doc = try JSONDecoder().decode(FestivalProgramDocument.self, from: data)
        let weeks = try doc.weeks.map { week in
            FestivalWeek(
                id: week.id,
                label: week.label,
                screenings: try week.screenings.map { try mapScreening($0) }
            )
        }
        return (seasonYear: doc.seasonYear, weeks: weeks)
    }

    /// Bundled `BundledSeason-{year}.json` in the app target (App Store screenshots, offline fallback).
    static func loadBundledSeason(year: Int) -> (seasonYear: Int, weeks: [FestivalWeek])? {
        guard let url = Bundle.main.url(forResource: "BundledSeason-\(year)", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? decodeProgram(from: data)
    }

    private static func mapScreening(_ doc: ScreeningDocument) throws -> Screening {
        guard let startsAt = parseDate(doc.startsAt), let sunsetAt = parseDate(doc.sunset) else {
            throw FestivalProgramFeedError.invalidDate(doc.id)
        }
        let resolvedPosterKey = PosterCatalog.stem(
            forDisplayTitle: doc.title,
            searchTitle: doc.searchTitle,
            explicit: doc.posterKey
                ?? doc.posterAssetName.flatMap { $0.count == 8 && $0.allSatisfy(\.isNumber) ? nil : $0 }
        )

        let resolvedSearchTitle: String? = {
            if let searchTitle = doc.searchTitle { return searchTitle }
            return resolvedPosterKey == "tbd" ? "" : doc.title
        }()

        return Screening(
            id: doc.id,
            title: doc.title,
            startsAt: startsAt,
            sunsetAt: sunsetAt,
            isCanceled: doc.isCanceled,
            synopsis: doc.synopsis,
            synopsisEn: doc.synopsisEn,
            runtimeMinutes: doc.runtimeMinutes,
            legalAge: doc.legalAge,
            recommendedAge: doc.recommendedAge,
            searchTitle: resolvedSearchTitle,
            posterURL: doc.posterURL,
            posterKey: resolvedPosterKey
        )
    }

    private static func parseDate(_ string: String) -> Date? {
        iso8601.date(from: string) ?? iso8601NoFraction.date(from: string)
    }
}

enum FestivalProgramFeedError: LocalizedError {
    case invalidDate(String)

    var errorDescription: String? {
        switch self {
        case .invalidDate(let id):
            return "Invalid ISO-8601 date for screening \(id)."
        }
    }
}
