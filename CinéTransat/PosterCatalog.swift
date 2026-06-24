//
//  PosterCatalog.swift
//  CinéTransat
//
//  Maps programme titles to poster filenames in hosting/public/posters/.
//  File stems must match exactly (including accents). Prefer English slugs when you add new art.
//

import Foundation

enum PosterCatalog {
    /// Display title (French programme) → filename stem in `hosting/public/posters/`.
    private static let stemsByTitle: [String: String] = [
        "Les Bronzés font du ski": "les-bronzes-font-du-ski",
        "Le Vieux qui ne voulait pas fêter son anniversaire": "le-vieux-qui-ne-voulait-pas-feter-son-anniversaire",
        "Shaun of the Dead": "shaun-of-the-dead",
        "Bottoms": "bottoms",
        "E.T. l'extra-terrestre": "e.t.-the-extraterrestial",
        "Les Mitchell contre les machines": "the-mitchells-vs-the-machines",
        "Soirée choréoké": "soirée-choréoké",
        "Au revoir là-haut": "au-revoir-la-haut",
        "Marinette": "marinette",
        "Ninjababy": "ninjababy",
        "Paddington 2": "paddington-2",
        "Soirée courts-métrages": "soirée-court-métrages",
        "The Holiday": "the-holiday",
        "Ma vie de Courgette": "ma-vie-de-courgette",
        "Terminator 2 : Le Jugement dernier": "terminator-2-judgment-day",
        "La Famille Asada": "la-famille-asada",
        "Puan": "puan",
        "Lost in Translation": "lost-in-translation",
        "Pulp Fiction": "pulp-fiction",
        "North by Northwest": "north-by-northwest",
        "Soirée rattrapage": "soirée-rattrapage",
        "Everything Everywhere All at Once": "everything-everywhere-all-at-once",
        "Bãhubali : The Beginning": "bahubali-the-beginning",
        "Bãhubali: The Beginning": "bahubali-the-beginning",
        "Le Fabuleux Destin d'Amélie Poulain": "le-fabuleux-destin-d'amelie-poulain",
        "Intouchables": "intouchables",
        "Back to the Future": "back-to-the-future",
        "La Famille Bélier": "la-famille-belier",
        "Billy Elliot": "billy-elliot",
        "Flow": "flow",
        "Sauvages": "sauvages",
        "Love and Other Disasters": "love-and-other-disasters",
        "Paddington": "paddington",
        "Soirées courts-métrages": "soiree-court-metrages",
        "I Am Not a Witch": "i-am-not-a-witch",
        "Singin' in the Rain": "singin-in-the-rain",
        "Wadjda": "wadjda",
        "The Girl Who Leapt Through Time": "the-girl-who-leapt-through-time",
        "CHOREOKE": "soiree-choreoke",
        "Jumanji: Welcome to the Jungle": "jumanji-welcome-to-the-jungle",
        "Bon Schuur Ticino (Ciao-ciao bourbine)": "bon-schuur-ticino",
        "Portrait de la jeune fille en feu": "portrait-de-la-jeune-fille-en-feu",
        "BlacKkKlansman": "blackkklansman",
        "Much Ado About Nothing": "much-ado-about-nothing",
        "The Mummy": "the-mummy",
        "Lo que quisimos ser": "lo-que-quisimos-ser",
        "Ocean's Eleven": "oceans-eleven",
        "Baahubali 2: The Conclusion": "baahubali-2-the-conclusion",
        "A Shaun the Sheep Movie: Farmaggedon": "a-shaun-the-sheep-movie-farmageddon",
        "A Shaun the Sheep Movie: Farmageddon": "a-shaun-the-sheep-movie-farmageddon",
        "Farmaggedon": "a-shaun-the-sheep-movie-farmageddon",
        "Farmageddon": "a-shaun-the-sheep-movie-farmageddon",
    ]

    /// Original theatrical release year (for detail screen).
    private static let releaseYearByPosterKey: [String: Int] = [
        "back-to-the-future": 1985,
        "la-famille-belier": 2014,
        "billy-elliot": 2000,
        "flow": 2024,
        "sauvages": 2023,
        "love-and-other-disasters": 2006,
        "paddington": 2014,
        "i-am-not-a-witch": 2017,
        "singin-in-the-rain": 1952,
        "wadjda": 2012,
        "the-girl-who-leapt-through-time": 2006,
        "jumanji-welcome-to-the-jungle": 2017,
        "bon-schuur-ticino": 2024,
        "portrait-de-la-jeune-fille-en-feu": 2019,
        "blackkklansman": 2018,
        "much-ado-about-nothing": 1993,
        "the-mummy": 1999,
        "lo-que-quisimos-ser": 2024,
        "oceans-eleven": 2001,
        "everything-everywhere-all-at-once": 2022,
        "baahubali-2-the-conclusion": 2017,
        "intouchables": 2011,
        "les-bronzes-font-du-ski": 1979,
        "e.t.-the-extraterrestial": 1982,
        "paddington-2": 2017,
        "pulp-fiction": 1994,
    ]

    static func releaseYear(forPosterKey key: String) -> Int? {
        releaseYearByPosterKey[key]
    }

    static func stem(forDisplayTitle title: String, searchTitle: String? = nil, explicit posterKey: String? = nil) -> String {
        if let posterKey, !posterKey.isEmpty {
            return posterKey
        }
        if let stem = stemsByTitle[title] {
            return stem
        }
        return PosterKey.slug(from: searchTitle ?? title)
    }

    /// Alternate stems for the same file on Hosting (legacy spelling / Firestore typos).
    static func alternateStems(for stem: String) -> [String] {
        switch stem {
        case "baahubali-the-beginning":
            return ["bahubali-the-beginning"]
        case "bahubali-the-beginning":
            return ["baahubali-the-beginning"]
        case "a-shaun-the-sheep-movie-farmageddon":
            return ["a-shaun-the-sheep-movie-farmaggedon"]
        case "a-shaun-the-sheep-movie-farmaggedon":
            return ["a-shaun-the-sheep-movie-farmageddon"]
        case "farmageddon", "farmaggedon":
            return ["a-shaun-the-sheep-movie-farmageddon", "a-shaun-the-sheep-movie-farmaggedon"]
        case "soirée-choréoké", "soiree-choreoke":
            return ["CHOREOKE"]
        case "CHOREOKE":
            return ["soiree-choreoke", "soirée-choréoké"]
        case "soirée-court-métrages", "soiree-court-metrages":
            return ["Soirées courts-métrages"]
        case "Soirées courts-métrages":
            return ["soiree-court-metrages", "soirée-court-métrages"]
        case "soirée-rattrapage", "soiree-rattrapage":
            return ["soirée-rattrapage", "soiree-rattrapage"]
        default:
            return []
        }
    }
}

enum PosterURLEncoding {
    /// Percent-encode for a Firebase Hosting / URL path segment (keeps Unicode letters).
    static func pathComponent(_ raw: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.insert(charactersIn: "'")
        return raw.addingPercentEncoding(withAllowedCharacters: allowed) ?? raw
    }
}
