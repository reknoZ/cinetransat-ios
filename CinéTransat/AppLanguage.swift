//
//  AppLanguage.swift
//  CinéTransat
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case fr
    case en

    var id: String { rawValue }

    var localeIdentifier: String {
        switch self {
        case .fr: return "fr_CH"
        case .en: return "en_US"
        }
    }

    var displayName: String {
        switch self {
        case .fr: return "Français"
        case .en: return "English"
        }
    }
}

enum L10n {
    static func text(_ key: String, language: AppLanguage) -> String {
        let table: [String: (fr: String, en: String)] = [
            "tab_program": ("Programme", "Program"),
            "tab_watchlist": ("Liste", "Watch List"),
            "tab_info": ("Infos", "Info"),
            "tab_festival": ("Festival", "Festival"),
            "tab_settings": ("Réglages", "Settings"),
            "settings_title": ("Réglages", "Settings"),
            "settings_language": ("Langue", "Language"),
            "settings_about_app": ("À propos de l'app", "About the app"),
            "settings_rate_app": ("Noter cette app", "Rate this app"),
            "settings_about_copy": ("CinéTransat est une app non officielle de démonstration pour consulter le programme, les infos utiles et votre liste de films.", "CinéTransat is an unofficial demo app to browse the program, practical info, and your movie list."),
            "settings_language_help": ("Le changement de langue s’applique immédiatement à l’interface principale.", "Language changes apply immediately to the main interface."),
            "about_title": ("À propos", "About"),
            "about_intro": ("Six semaines, quatre soirs par semaine : cinéma en plein air après le coucher du soleil.", "Six weeks, four nights each week: open-air cinema after sunset."),
            "about_data_copy": ("Les données affichées reprennent un programme type (saison \(FestivalProgramData.demoYear)) pour le développement : remplacez-les par votre JSON ou votre CMS lorsque le programme officiel est prêt.", "The data shown is a sample schedule (season \(FestivalProgramData.demoYear)) for development: replace it with your JSON feed or CMS when the official schedule is ready."),
            "about_poster_copy": ("Affiches : ajoutez au catalogue d’assets un jeu d’images par soirée, nommé exactement comme la date de la séance au format AAAAMMJJ (ex. 20250710). Tant qu’une image n’existe pas, l’app affiche le fond générique.", "Posters: add one image set per screening date in the asset catalog, named exactly as YYYYMMDD (for example, 20250710). Until a matching image exists, the app shows the generic placeholder tile."),
        ]
        let pair = table[key] ?? (fr: key, en: key)
        switch language {
        case .fr: return pair.fr
        case .en: return pair.en
        }
    }
}

func localizedProgramTitle(year: Int, language: AppLanguage) -> String {
    switch language {
    case .fr:
        return "Programme \(year)"
    case .en:
        return "Program \(year)"
    }
}

func localizedWeekLabel(number: Int, weekLabel: String, language: AppLanguage) -> String {
    switch language {
    case .fr:
        return "Semaine \(number) · \(weekLabel)"
    case .en:
        return "Week \(number) · \(weekLabel)"
    }
}

extension Screening {
    func localizedTitle(language: AppLanguage) -> String {
        guard language == .en else { return title }
        let englishOverrides: [String: String] = [
            "Soirée choréoké": "Choréoké Night",
            "Soirée courts-métrages": "Short Film Night",
            "Soirée rattrapage": "Make Up Night",
        ]
        return englishOverrides[title] ?? title
    }
}
