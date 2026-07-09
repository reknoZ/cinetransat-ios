//
//  FestivalProgramFeed.swift
//  CinéTransat
//

import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

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
    let audioLanguage: String?
    let audioLanguageEn: String?
    let subtitleLanguage: String?
    let subtitleLanguageEn: String?
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

    /// Firestore snapshot payloads may contain `Timestamp` values — `JSONSerialization` traps on those.
    static func decodeProgram(from firestoreData: [String: Any]) throws -> (seasonYear: Int, weeks: [FestivalWeek]) {
        let sanitized = jsonSafeFirestoreValue(firestoreData)
        guard let object = sanitized as? [String: Any] else {
            throw FestivalProgramFeedError.invalidDocument
        }
        let payload = try JSONSerialization.data(withJSONObject: object)
        return try decodeProgram(from: payload)
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
            audioLanguage: doc.audioLanguage,
            audioLanguageEn: doc.audioLanguageEn,
            subtitleLanguage: doc.subtitleLanguage,
            subtitleLanguageEn: doc.subtitleLanguageEn,
            searchTitle: resolvedSearchTitle,
            posterURL: doc.posterURL,
            posterKey: resolvedPosterKey
        )
    }

    private static func parseDate(_ string: String) -> Date? {
        iso8601.date(from: string) ?? iso8601NoFraction.date(from: string)
    }

    private static func jsonSafeFirestoreValue(_ value: Any) -> Any {
        #if canImport(FirebaseFirestore)
        if let timestamp = value as? Timestamp {
            return isoString(from: timestamp.dateValue())
        }
        #endif
        if let dict = value as? [String: Any] {
            return dict.mapValues { jsonSafeFirestoreValue($0) }
        }
        if let array = value as? [Any] {
            return array.map { jsonSafeFirestoreValue($0) }
        }
        return value
    }

    private static func isoString(from date: Date) -> String {
        iso8601NoFraction.string(from: date)
    }
}

enum FestivalProgramFeedError: LocalizedError {
    case invalidDate(String)
    case invalidDocument

    var errorDescription: String? {
        switch self {
        case .invalidDate(let id):
            return "Invalid ISO-8601 date for screening \(id)."
        case .invalidDocument:
            return "Invalid Firestore programme document."
        }
    }
}
