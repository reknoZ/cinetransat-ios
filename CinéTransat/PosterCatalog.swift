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
        "La Grande Vadrouille": "la-grande-vadrouille",
        "Grease": "grease",
        "Back to the Future": "back-to-the-future",
        "The Grand Budapest Hotel": "the-grand-budapest-hotel",
        "Jurassic Park": "jurassic-park",
        "Kung Fu Panda": "kung-fu-panda",
        "Les Choristes": "les-choristes",
        "Delicatessen": "delicatessen",
        "Parasite": "parasite",
        "Flashdance": "flashdance",
        "Notting Hill": "notting-hill",
        "Kirikou et la Sorcière": "kirikou-et-la-sorciere",
        "Raiders of the Lost Ark": "raiders-of-the-lost-ark",
        "Your Name.": "your-name",
        "Cinema Paradiso": "cinema-paradiso",
        "Forrest Gump": "forrest-gump",
        "The Matrix": "the-matrix",
        "Casablanca": "casablanca",
        "RRR": "rrr",
        "Le Dîner de cons": "le-diner-de-cons",
        "A Shaun the Sheep Movie: Farmaggedon": "a-shaun-the-sheep-movie-farmageddon",
        "A Shaun the Sheep Movie: Farmageddon": "a-shaun-the-sheep-movie-farmageddon",
        "Farmaggedon": "a-shaun-the-sheep-movie-farmageddon",
        "Farmageddon": "a-shaun-the-sheep-movie-farmageddon",
    ]

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
        case "soirée-choréoké":
            return ["soiree-choreoke"]
        case "soiree-choreoke":
            return ["soirée-choréoké"]
        case "soirée-court-métrages":
            return ["soiree-court-metrages"]
        case "soiree-court-metrages":
            return ["soirée-court-métrages"]
        case "soirée-rattrapage":
            return ["soiree-rattrapage"]
        case "soiree-rattrapage":
            return ["soirée-rattrapage"]
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
