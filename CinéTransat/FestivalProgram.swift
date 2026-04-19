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
    let id: UUID
    let title: String
    let startsAt: Date
    let sunsetAt: Date
    let isCanceled: Bool
    let synopsis: String
    let runtimeMinutes: Int?
    let searchTitle: String
    /// Asset catalog image set name, usually `YYYYMMDD` matching the screening date. If missing from the bundle, the generic tile is shown.
    let posterAssetName: String?
    /// Stable key for persistence (watch list, future “who’s going” aggregates), based on screening calendar date.
    var watchListID: String {
        let dc = FestivalCalendar.current.dateComponents([.year, .month, .day], from: startsAt)
        return String(
            format: "%04d%02d%02d",
            dc.year ?? 0,
            dc.month ?? 0,
            dc.day ?? 0
        )
    }

    init(
        id: UUID = UUID(),
        title: String,
        startsAt: Date,
        sunsetAt: Date,
        isCanceled: Bool,
        synopsis: String,
        runtimeMinutes: Int?,
        searchTitle: String? = nil,
        posterAssetName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startsAt = startsAt
        self.sunsetAt = sunsetAt
        self.isCanceled = isCanceled
        self.synopsis = synopsis
        self.runtimeMinutes = runtimeMinutes
        self.searchTitle = searchTitle ?? title
        self.posterAssetName = posterAssetName
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

enum FestivalProgramData {
    /// Programme indicatif basé sur la saison 2025 (jeu.–dim. après le coucher du soleil).
    static let demoYear = 2025

    static let weeks: [FestivalWeek] = {
        let cal = FestivalCalendar.current

        func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 21, _ min: Int = 45) -> Date {
            var dc = DateComponents()
            dc.year = y
            dc.month = m
            dc.day = d
            dc.hour = h
            dc.minute = min
            return cal.date(from: dc)!
        }

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
            searchTitle: String? = nil
        ) -> Screening {
            let posterId = String(format: "%04d%02d%02d", y, m, d)
            return Screening(
                title: title,
                startsAt: date(y, m, d),
                sunsetAt: sunset(y, m, d),
                isCanceled: canceled,
                synopsis: blurb,
                runtimeMinutes: minutes,
                searchTitle: searchTitle,
                posterAssetName: posterId
            )
        }

        return [
            FestivalWeek(
                id: "2025-w1",
                label: "10–13 juillet",
                screenings: [
                    s(title: "Les Bronzés font du ski", y: demoYear, m: 7, d: 10, minutes: 90, blurb: "Comédie culte des Bronzés coincés à la montagne."),
                    s(title: "Le Vieux qui ne voulait pas fêter son anniversaire", y: demoYear, m: 7, d: 11, minutes: 114, blurb: "Road movie absurde et tendre entre Suède et explosion."),
                    s(title: "Shaun of the Dead", y: demoYear, m: 7, d: 12, minutes: 99, blurb: "Zombie comedy britannique iconique."),
                    s(title: "Bottoms", y: demoYear, m: 7, d: 13, minutes: 91, blurb: "Comédie déjantée de lycée et club de combat improbable."),
                ]
            ),
            FestivalWeek(
                id: "2025-w2",
                label: "17–20 juillet",
                screenings: [
                    s(title: "E.T. l'extra-terrestre", y: demoYear, m: 7, d: 17, minutes: 115, blurb: "Le classique Spielberg sur l'amitié et le retour à la maison."),
                    s(title: "Les Mitchell contre les machines", y: demoYear, m: 7, d: 18, minutes: 114, blurb: "Road trip familial face à une révolte des robots."),
                    s(title: "Soirée choréoké", y: demoYear, m: 7, d: 19, canceled: true, minutes: nil, blurb: "Soirée spéciale — annulée en raison des conditions."),
                    s(title: "Au revoir là-haut", y: demoYear, m: 7, d: 20, canceled: true, minutes: 117, blurb: "Drame poétique post-Grande Guerre — séance annulée."),
                ]
            ),
            FestivalWeek(
                id: "2025-w3",
                label: "24–27 juillet",
                screenings: [
                    s(title: "Marinette", y: demoYear, m: 7, d: 24, minutes: 95, blurb: "Biopic sportif sur la footballeuse Marinette Pichon."),
                    s(title: "Ninjababy", y: demoYear, m: 7, d: 25, minutes: 103, blurb: "Comédie norvégienne d'une grossesse dessinée en ninja."),
                    s(title: "Paddington 2", y: demoYear, m: 7, d: 26, canceled: true, minutes: 103, blurb: "Aventures de l'ours le plus aimable de Londres — séance annulée."),
                    s(title: "Soirée courts-métrages", y: demoYear, m: 7, d: 27, canceled: true, minutes: nil, blurb: "Programme de courts — annulé."),
                ]
            ),
            FestivalWeek(
                id: "2025-w4",
                label: "31 juillet – 3 août",
                screenings: [
                    s(title: "The Holiday", y: demoYear, m: 7, d: 31, minutes: 136, blurb: "Romance hivernale entre Los Angeles et la campagne anglaise."),
                    s(title: "Ma vie de Courgette", y: demoYear, m: 8, d: 1, minutes: 66, blurb: "Stop-motion délicat sur l'enfance et la résilience."),
                    s(title: "Terminator 2 : Le Jugement dernier", y: demoYear, m: 8, d: 2, minutes: 137, blurb: "Science-fiction d'action avec Schwarzenegger."),
                    s(title: "La Famille Asada", y: demoYear, m: 8, d: 3, minutes: 127, blurb: "Drame familial japonais autour d'un restaurant et des liens."),
                ]
            ),
            FestivalWeek(
                id: "2025-w5",
                label: "7–10 août",
                screenings: [
                    s(title: "Puan", y: demoYear, m: 8, d: 7, minutes: 110, blurb: "Comédie argentine sur l'université, la politique et l'amitié."),
                    s(title: "Lost in Translation", y: demoYear, m: 8, d: 8, minutes: 102, blurb: "Rencontre fugace à Tokyo entre deux âmes en décalage."),
                    s(title: "Pulp Fiction", y: demoYear, m: 8, d: 9, minutes: 154, blurb: "Anthologie criminelle signée Tarantino."),
                    s(title: "North by Northwest", y: demoYear, m: 8, d: 10, minutes: 136, blurb: "Thriller hitchcockien à travers les États-Unis."),
                ]
            ),
            FestivalWeek(
                id: "2025-w6",
                label: "14–17 août",
                screenings: [
                    s(title: "Soirée rattrapage", y: demoYear, m: 8, d: 14, minutes: nil, blurb: "Programme variable : films manqués ou invités de la saison."),
                    s(title: "Everything Everywhere All at Once", y: demoYear, m: 8, d: 15, minutes: 139, blurb: "Multivers délirant et émouvant sur les choix de vie."),
                    s(title: "Bãhubali : The Beginning", y: demoYear, m: 8, d: 16, minutes: 159, blurb: "Épopée indienne grand spectacle.", searchTitle: "Baahubali The Beginning"),
                    s(title: "Le Fabuleux Destin d'Amélie Poulain", y: demoYear, m: 8, d: 17, minutes: 122, blurb: "Paris poétique et jeux du hasard."),
                ]
            ),
        ]
    }()
}
