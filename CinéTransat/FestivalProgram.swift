//
//  FestivalProgram.swift
//  CinéTransat
//

import Foundation

enum FestivalCalendar {
    static var current: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        c.locale = Locale(identifier: "fr_CH")
        return c
    }

    static var startOfToday: Date {
        startOfDay(for: Date())
    }

    static func startOfDay(for date: Date) -> Date {
        current.startOfDay(for: date)
    }
}

extension Array where Element == Screening {
    /// Screenings scheduled on `date` in Geneva (includes canceled).
    func screenings(on date: Date) -> [Screening] {
        let targetDay = FestivalCalendar.startOfDay(for: date)
        return filter { $0.festivalDay == targetDay }
            .sorted { $0.startsAt < $1.startsAt }
    }

    func screeningsToday() -> [Screening] {
        screenings(on: Date())
    }
}

extension Array where Element == FestivalWeek {
    /// Week pager index when opening the Program tab.
    /// Today's week if there is a screening tonight; otherwise the next week with an upcoming screening.
    func indexOfWeek(for date: Date = Date()) -> Int {
        guard !isEmpty else { return 0 }
        let today = FestivalCalendar.startOfDay(for: date)
        let allScreenings = flatMap(\.orderedScreenings)

        if !allScreenings.screenings(on: date).isEmpty,
           let todayWeek = firstIndex(where: { week in
               week.orderedScreenings.contains { $0.festivalDay == today }
           }) {
            return todayWeek
        }

        if let upcoming = firstIndex(where: { week in
            week.orderedScreenings.contains { $0.festivalDay >= today }
        }) {
            return upcoming
        }

        return count - 1
    }
}

struct FestivalWeek: Identifiable, Hashable {
    let id: String
    let label: String
    let screenings: [Screening]

    var orderedScreenings: [Screening] {
        screenings.sorted { $0.startsAt < $1.startsAt }
    }
}

struct Screening: Identifiable, Hashable {
    /// Stable screening day key in `yyyyMMdd` format (also used for poster lookup).
    let id: String
    let title: String
    let startsAt: Date
    let sunsetAt: Date
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
    let searchTitle: String
    /// Optional HTTPS poster URL (Firestore). Takes priority over `posterBaseURL`.
    let posterURL: String?
    /// Which poster file to load (`{posterKey}.jpg` on your CDN / Hosting). Defaults from film title; override for catch-up nights.
    let posterKey: String

    /// Stable key for persistence (watch list, future “who’s going” aggregates).
    var watchListID: String {
        id
    }

    init(
        id: String,
        title: String,
        startsAt: Date? = nil,
        sunsetAt: Date,
        isCanceled: Bool,
        synopsis: String,
        synopsisEn: String? = nil,
        runtimeMinutes: Int?,
        legalAge: Int? = nil,
        recommendedAge: Int? = nil,
        audioLanguage: String? = nil,
        audioLanguageEn: String? = nil,
        subtitleLanguage: String? = nil,
        subtitleLanguageEn: String? = nil,
        searchTitle: String? = nil,
        posterURL: String? = nil,
        posterKey: String? = nil
    ) {
        self.id = id
        self.title = title
        self.sunsetAt = sunsetAt
        let fallbackStart = startsAt ?? Self.defaultStartTime(for: id, sunsetAt: sunsetAt)
        self.startsAt = Self.canonicalStartTime(for: id, fallback: fallbackStart)
        self.isCanceled = isCanceled
        self.synopsis = synopsis
        self.synopsisEn = synopsisEn
        self.runtimeMinutes = runtimeMinutes
        self.legalAge = legalAge
        self.recommendedAge = recommendedAge
        self.audioLanguage = audioLanguage
        self.audioLanguageEn = audioLanguageEn
        self.subtitleLanguage = subtitleLanguage
        self.subtitleLanguageEn = subtitleLanguageEn
        self.searchTitle = searchTitle ?? title
        self.posterURL = posterURL
        self.posterKey = PosterCatalog.stem(forDisplayTitle: title, searchTitle: searchTitle, explicit: posterKey)
    }

    /// Official 2026 projection starts (Europe/Zurich). Sync with `PROJECTION_START_2026` in `scripts/generate_seed_data.py`.
    private static let projectionStartByScreeningID: [String: (hour: Int, minute: Int)] = [
        "20260709": (21, 44), "20260710": (21, 43), "20260711": (21, 43), "20260712": (21, 42),
        "20260716": (21, 39), "20260717": (21, 38), "20260718": (21, 37), "20260719": (21, 0),
        "20260723": (21, 31), "20260724": (21, 30), "20260725": (21, 29), "20260726": (21, 28),
        "20260730": (21, 0), "20260731": (21, 21), "20260801": (21, 20), "20260802": (21, 19),
        "20260806": (21, 13), "20260807": (21, 11), "20260808": (21, 10), "20260809": (21, 8),
        "20260813": (21, 1), "20260814": (21, 0), "20260815": (20, 58), "20260816": (20, 56),
    ]

    static func canonicalStartTime(for id: String, fallback: Date) -> Date {
        projectionStartDate(for: id) ?? fallback
    }

    private static func projectionStartDate(for id: String) -> Date? {
        guard let start = projectionStartByScreeningID[id],
              let day = dayKeyFormatter.date(from: id) else { return nil }
        var dc = FestivalCalendar.current.dateComponents([.year, .month, .day], from: day)
        dc.hour = start.hour
        dc.minute = start.minute
        return FestivalCalendar.current.date(from: dc)
    }

    private static func defaultStartTime(for id: String, sunsetAt: Date) -> Date {
        if let projected = projectionStartDate(for: id) { return projected }
        guard let day = dayKeyFormatter.date(from: id) else {
            return sunsetAt
        }
        var dc = FestivalCalendar.current.dateComponents([.year, .month, .day], from: day)
        dc.hour = 21
        dc.minute = 45
        return FestivalCalendar.current.date(from: dc) ?? day
    }

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = FestivalCalendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        f.dateFormat = "yyyyMMdd"
        return f
    }()

    /// Screening day (Geneva) is before today — shown dimmed with a “past” badge in the UI.
    var hasPassed: Bool {
        festivalDay < FestivalCalendar.startOfToday
    }

    /// True when this screening is scheduled for today in Geneva.
    var isFestivalDayToday: Bool {
        festivalDay == FestivalCalendar.startOfToday
    }

    /// Calendar day of this screening in Geneva (Europe/Zurich).
    var festivalDay: Date {
        FestivalCalendar.startOfDay(for: startsAt)
    }

    /// Placeholder poster (grey + clapperboard) — programme not yet announced.
    var usesTBDPlaceholderPoster: Bool {
        posterKey == "tbd"
    }

    /// Special evenings (Soirée / CHOREOKE) — no IMDb / Allociné links.
    var isSoireeEvening: Bool {
        let foldedTitle = title
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
        if foldedTitle.hasPrefix("soiree") { return true }
        if foldedTitle == "choreoke" { return true }
        let foldedKey = posterKey
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
        return foldedKey.hasPrefix("soiree")
    }

    var isRattrapageEvening: Bool {
        if RattrapageVotingDebug.isPretendRattrapage(id) { return true }
        let foldedTitle = title
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
        if foldedTitle.contains("rattrapage") { return true }
        let foldedKey = posterKey
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
        return foldedKey.contains("rattrapage")
    }

    /// IMDb / Allociné search links — off for TBD and Soirée evenings.
    var externalSearchLinksEnabled: Bool {
        !usesTBDPlaceholderPoster && !isSoireeEvening && !searchTitle.isEmpty
    }

    /// Programme title announced (not a TBD placeholder screening).
    var isProgramAnnounced: Bool {
        !usesTBDPlaceholderPoster
    }
}

extension Array where Element == Screening {
    /// Canceled films for Soirée Rattrapage / Catch Up Day, ordered by programme date.
    /// Always includes announced cancellations (even a single film). Interactive voting is gated separately by `rattrapageVotingOpen`.
    func canceledForRattrapage(excludingRattrapageID: String? = nil) -> [Screening] {
        filter { screening in
            (screening.isCanceled || RattrapageVotingDebug.isPretendCanceled(screening.id))
                && screening.isProgramAnnounced
                && !screening.isRattrapageEvening
                && screening.id != excludingRattrapageID
        }
        .sorted { $0.startsAt < $1.startsAt }
    }
}

enum ExternalFilmLinks {
    static func imdbSearchURL(for title: String) -> URL {
        var c = URLComponents(string: "https://www.imdb.com/find/")!
        c.queryItems = [
            URLQueryItem(name: "q", value: title),
            URLQueryItem(name: "s", value: "tt"),
            URLQueryItem(name: "ttype", value: "ft"),
        ]
        return c.url!
    }

    static func allocineSearchURL(for title: String) -> URL {
        var c = URLComponents(string: "https://www.allocine.fr/recherche/")!
        c.queryItems = [URLQueryItem(name: "q", value: title)]
        return c.url!
    }
}

/// Bundled fallback programme used when Firebase is not configured or offline on first launch.
enum FestivalProgramBootstrap {
    static let seasonYear = 2025

    static let weeks: [FestivalWeek] = {
        let cal = FestivalCalendar.current

        func sunset(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 21, _ min: Int = 18) -> Date {
            var dc = DateComponents()
            dc.year = y
            dc.month = m
            dc.day = d
            dc.hour = h
            dc.minute = min
            return cal.date(from: dc)!
        }

        func s(
            title: String,
            y: Int, m: Int, d: Int,
            canceled: Bool = false,
            minutes: Int?,
            blurb: String,
            searchTitle: String? = nil,
            posterKey: String? = nil
        ) -> Screening {
            let dayId = String(format: "%04d%02d%02d", y, m, d)
            return Screening(
                id: dayId,
                title: title,
                sunsetAt: sunset(y, m, d),
                isCanceled: canceled,
                synopsis: blurb,
                runtimeMinutes: minutes,
                searchTitle: searchTitle,
                posterKey: posterKey
            )
        }

        return [
            FestivalWeek(
                id: "2025-w1",
                label: "10–13 juillet",
                screenings: [
                    s(title: "Les Bronzés font du ski", y: seasonYear, m: 7, d: 10, minutes: 90, blurb: "Comédie culte des Bronzés coincés à la montagne."),
                    s(title: "Le Vieux qui ne voulait pas fêter son anniversaire", y: seasonYear, m: 7, d: 11, minutes: 114, blurb: "Road movie absurde et tendre entre Suède et explosion."),
                    s(title: "Shaun of the Dead", y: seasonYear, m: 7, d: 12, minutes: 99, blurb: "Zombie comedy britannique iconique."),
                    s(title: "Bottoms", y: seasonYear, m: 7, d: 13, minutes: 91, blurb: "Comédie déjantée de lycée et club de combat improbable."),
                ]
            ),
            FestivalWeek(
                id: "2025-w2",
                label: "17–20 juillet",
                screenings: [
                    s(title: "E.T. l'extra-terrestre", y: seasonYear, m: 7, d: 17, minutes: 115, blurb: "Le classique Spielberg sur l'amitié et le retour à la maison."),
                    s(title: "Les Mitchell contre les machines", y: seasonYear, m: 7, d: 18, minutes: 114, blurb: "Road trip familial face à une révolte des robots."),
                    s(title: "Soirée choréoké", y: seasonYear, m: 7, d: 19, canceled: true, minutes: nil, blurb: "Soirée spéciale — annulée en raison des conditions."),
                    s(title: "Au revoir là-haut", y: seasonYear, m: 7, d: 20, canceled: true, minutes: 117, blurb: "Drame poétique post-Grande Guerre — séance annulée."),
                ]
            ),
            FestivalWeek(
                id: "2025-w3",
                label: "24–27 juillet",
                screenings: [
                    s(title: "Marinette", y: seasonYear, m: 7, d: 24, minutes: 95, blurb: "Biopic sportif sur la footballeuse Marinette Pichon."),
                    s(title: "Ninjababy", y: seasonYear, m: 7, d: 25, minutes: 103, blurb: "Comédie norvégienne d'une grossesse dessinée en ninja."),
                    s(title: "Paddington 2", y: seasonYear, m: 7, d: 26, canceled: true, minutes: 103, blurb: "Aventures de l'ours le plus aimable de Londres — séance annulée."),
                    s(title: "Soirée courts-métrages", y: seasonYear, m: 7, d: 27, canceled: true, minutes: nil, blurb: "Programme de courts — annulé."),
                ]
            ),
            FestivalWeek(
                id: "2025-w4",
                label: "31 juillet – 3 août",
                screenings: [
                    s(title: "The Holiday", y: seasonYear, m: 7, d: 31, minutes: 136, blurb: "Romance hivernale entre Los Angeles et la campagne anglaise."),
                    s(title: "Ma vie de Courgette", y: seasonYear, m: 8, d: 1, minutes: 66, blurb: "Stop-motion délicat sur l'enfance et la résilience."),
                    s(title: "Terminator 2 : Le Jugement dernier", y: seasonYear, m: 8, d: 2, minutes: 137, blurb: "Science-fiction d'action avec Schwarzenegger."),
                    s(title: "La Famille Asada", y: seasonYear, m: 8, d: 3, minutes: 127, blurb: "Drame familial japonais autour d'un restaurant et des liens."),
                ]
            ),
            FestivalWeek(
                id: "2025-w5",
                label: "7–10 août",
                screenings: [
                    s(title: "Puan", y: seasonYear, m: 8, d: 7, minutes: 110, blurb: "Comédie argentine sur l'université, la politique et l'amitié."),
                    s(title: "Lost in Translation", y: seasonYear, m: 8, d: 8, minutes: 102, blurb: "Rencontre fugace à Tokyo entre deux âmes en décalage."),
                    s(title: "Pulp Fiction", y: seasonYear, m: 8, d: 9, minutes: 154, blurb: "Anthologie criminelle signée Tarantino."),
                    s(title: "North by Northwest", y: seasonYear, m: 8, d: 10, minutes: 136, blurb: "Thriller hitchcockien à travers les États-Unis."),
                ]
            ),
            FestivalWeek(
                id: "2025-w6",
                label: "14–17 août",
                screenings: [
                    s(
                        title: "Soirée rattrapage",
                        y: seasonYear, m: 8, d: 14,
                        minutes: nil,
                        blurb: "Programme variable : films manqués ou invités de la saison.",
                        posterKey: "paddington-2"
                    ),
                    s(title: "Everything Everywhere All at Once", y: seasonYear, m: 8, d: 15, minutes: 139, blurb: "Multivers délirant et émouvant sur les choix de vie."),
                    s(title: "Bãhubali : The Beginning", y: seasonYear, m: 8, d: 16, minutes: 159, blurb: "Épopée indienne grand spectacle.", searchTitle: "Baahubali The Beginning"),
                    s(title: "Le Fabuleux Destin d'Amélie Poulain", y: seasonYear, m: 8, d: 17, minutes: 122, blurb: "Paris poétique et jeux du hasard."),
                ]
            ),
        ]
    }()

    /// Temporary helper to export screenings for backend/bootstrap work.
    /// - Key: screening date in `yyyyMMdd` (same key used for poster lookup).
    /// - Value: all other screening fields as a JSON-like dictionary.
    static func exportScreeningsByDateDictionary() -> [String: [String: Any]] {
        Dictionary(
            uniqueKeysWithValues: weeks.flatMap { week in
                week.orderedScreenings.map { screening in
                    (
                        screening.watchListID,
                        [
                            "id": screening.id,
                            "title": screening.title,
                            "startsAt": iso8601String(screening.startsAt),
                            "sunset": iso8601String(screening.sunsetAt),
                            "isCanceled": screening.isCanceled,
                            "synopsis": screening.synopsis,
                            "synopsisEn": screening.synopsisEn as Any,
                            "runtimeMinutes": screening.runtimeMinutes as Any,
                            "legalAge": screening.legalAge as Any,
                            "recommendedAge": screening.recommendedAge as Any,
                            "audioLanguage": screening.audioLanguage as Any,
                            "audioLanguageEn": screening.audioLanguageEn as Any,
                            "subtitleLanguage": screening.subtitleLanguage as Any,
                            "subtitleLanguageEn": screening.subtitleLanguageEn as Any,
                            "searchTitle": screening.searchTitle,
                            "posterURL": screening.posterURL as Any,
                            "posterKey": screening.posterKey,
                            "weekId": week.id,
                            "weekLabel": week.label,
                        ]
                    )
                }
            }
        )
    }

    /// Temporary helper returning pretty-printed JSON export data.
    static func exportScreeningsJSONData() throws -> Data {
        let payload = exportScreeningsByDateDictionary()
        guard JSONSerialization.isValidJSONObject(payload) else {
            throw NSError(
                domain: "CineTransat.Export",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Export payload is not valid JSON."]
            )
        }
        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    /// Firestore seed payload for document `seasons/{seasonYear}`.
    static func exportProgramDocumentJSONData(weeks: [FestivalWeek], seasonYear: Int) throws -> Data {
        let formatter = iso8601Formatter
        let weekDocs = weeks.map { week in
            FestivalWeekDocument(
                id: week.id,
                label: week.label,
                screenings: week.orderedScreenings.map { screening in
                    ScreeningDocument(
                        id: screening.id,
                        title: screening.title,
                        startsAt: formatter.string(from: screening.startsAt),
                        sunset: formatter.string(from: screening.sunsetAt),
                        isCanceled: screening.isCanceled,
                        synopsis: screening.synopsis,
                        synopsisEn: screening.synopsisEn,
                        runtimeMinutes: screening.runtimeMinutes,
                        legalAge: screening.legalAge,
                        recommendedAge: screening.recommendedAge,
                        audioLanguage: screening.audioLanguage,
                        audioLanguageEn: screening.audioLanguageEn,
                        subtitleLanguage: screening.subtitleLanguage,
                        subtitleLanguageEn: screening.subtitleLanguageEn,
                        searchTitle: screening.searchTitle,
                        posterURL: screening.posterURL,
                        posterKey: screening.posterKey
                    )
                }
            )
        }
        let document = FestivalProgramDocument(
            schemaVersion: 3,
            seasonYear: seasonYear,
            updatedAt: formatter.string(from: Date()),
            weeks: weekDocs
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func iso8601String(_ date: Date) -> String {
        iso8601Formatter.string(from: date)
    }
}
