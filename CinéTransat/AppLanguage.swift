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
            "tab_watchlist": ("À voir", "Watchlist"),
            "watchlist_empty_title": ("Rien dans votre liste", "Nothing on your watch list yet"),
            "watchlist_empty_body": (
                "Touchez l’icône signet sur une affiche dans Programme pour marquer une séance.",
                "Tap the bookmark icon on a poster in program to mark a screening you plan to see."
            ),
            "tab_info": ("Infos", "Info"),
            "tab_festival": ("Festival", "Festival"),
            "tab_settings": ("Réglages", "Settings"),
            "settings_title": ("Réglages", "Settings"),
            "settings_language": ("Langue", "Language"),
            "settings_about_section": ("À propos de CinéTransat !", "About CinéTransat!"),
            "settings_rate_app": ("Noter cette app", "Rate this app"),
            "settings_send_feedback": ("Envoyer un commentaire", "Send feedback"),
            "settings_feedback_subject": ("CinéTransat — commentaire", "CinéTransat — feedback"),
            "settings_feedback_unavailable": (
                "Impossible d’ouvrir Mail. Écrivez à %@.",
                "Unable to open Mail. Please email %@."
            ),
            "settings_about_version": ("Version", "Version"),
            "settings_language_help": ("Le changement de langue s’applique immédiatement à l’interface principale.", "Language changes apply immediately to the main interface."),
            "about_intro": ("Six semaines, quatre soirs par semaine : cinéma gratuit en plein air après le coucher du soleil.", "Six weeks, four nights each week: free open-air cinema after sunset."),
            "festival_rattrapage_vote": ("Vote pour la Soirée Rattrapage : bientôt disponible", "Vote for Soirée Rattrapage: coming soon"),
            "screening_passed": ("Passé", "Passed"),
            "detail_legal_age": ("Âge légal", "Legal age"),
            "detail_recommended_age": ("Âge suggéré", "Recommended age"),
            "detail_sunset": ("Coucher du soleil", "Sunset"),
            "detail_start": ("Début de la projection", "Screening start"),
            "detail_duration": ("Durée", "Duration"),
            "detail_duration_variable": ("Variable", "Variable"),
            "detail_search_imdb": ("IMDb", "IMDb"),
            "detail_search_allocine": ("Allociné", "Allociné"),
            "detail_screening_canceled": ("Séance annulée", "Screening canceled"),
            "detail_film_year": ("Année du film", "Film year"),
            "detail_previous_film": ("Film précédent", "Previous film"),
            "detail_next_film": ("Film suivant", "Next film"),
            "screening_canceled_badge": ("Annulé", "Canceled"),
            "program_weeks_title": ("Semaines", "Weeks"),
            "program_pick_week_title": ("Choisir une semaine", "Choose a week"),
            "program_pick_week_body": ("Sélectionnez une ligne dans la colonne de gauche.", "Select a row in the sidebar."),
            "program_week_accessibility": ("Semaine %d", "Week %d"),
            "watchlist_add": ("Ajouter à la liste", "Add to watch list"),
            "watchlist_remove": ("Retirer de la liste", "Remove from watch list"),
            "program_season_picker": ("Choisir la saison", "Choose season"),
            "program_season_picker_hint": ("Faites défiler pour choisir une autre saison", "Scroll to choose another season"),
            "program_refresh_posters": ("Actualiser les affiches", "Refresh posters"),
            "info_nav_title": ("Infos pratiques", "Practical info"),
            "info_free_title": ("Projections gratuites", "Free screenings"),
            "info_free_body": (
                "Les projections de CinéTransat ont lieu dans le parc public de la Perle du Lac à Genève, et sont gratuites. Elles sont accessibles à tou.te.s et sans réservation !",
                "CinéTransat screenings take place in the public park at La Perle du Lac in Geneva and are free of charge. Everyone is welcome and no reservation is required!"
            ),
            "info_schedule_title": ("Jours et horaires", "Days and times"),
            "info_schedule_body": (
                """
                Projections du jeudi au dimanche, du 9 juillet au 16 août %@.

                Début des films à la tombée de la nuit, entre 22h00 (mi-juillet) et 21h15 (fin août).

                Buvette, location de transats et animations dès 19h00.

                Fin de la soirée vers minuit.
                """,
                """
                Screenings run Thursday through Sunday, from 9 July to 16 August %@.

                Films start at nightfall, between 10:00 p.m. (mid-July) and 9:15 p.m. (late August).

                Bar, deck chair rental, and activities from 7:00 p.m.

                Evenings end around midnight.
                """
            ),
            "info_age_title": ("Âge légal", "Age ratings"),
            "info_age_body": (
                """
                L’âge légal pour le visionnage des films varie de 7 à 16 ans.

                Merci de respecter ces consignes et de ne pas venir avec des enfants plus jeunes que l’âge légal indiqué. Des contrôles pourront être effectués par la Brigade des mineurs.
                """,
                """
                Legal viewing ages for films range from 7 to 16.

                Please follow these guidelines and do not bring children younger than the stated rating. Checks may be carried out by the juvenile brigade.
                """
            ),
            "info_languages_title": ("Langues et sous-titres", "Languages and subtitles"),
            "info_languages_body": (
                """
                Les films sont diffusés en version originale afin de préserver au mieux la qualité de l’œuvre et son empreinte culturelle. Genève étant une ville internationale, il nous tient à cœur de toucher tous les publics et communautés représentés.

                De manière générale, les films en français sont sous-titrés en anglais ; tous les autres films sont sous-titrés en français.

                Les langues et les sous-titres sont indiqués dans le programme.
                """,
                """
                Films are shown in their original language to preserve the work and its cultural context. As Geneva is an international city, we aim to reach all audiences and communities represented.

                In general, French-language films are subtitled in English; all other films are subtitled in French.

                Languages and subtitles are listed in the program.
                """
            ),
            "info_bar_title": ("Buvette et pique-niques", "Bar and picnics"),
            "info_bar_body": (
                """
                La buvette CinéTransat proposent des boissons uniquement. Paiement cash, carte et par Twint. Pas de vente de nourriture sur place. Vous pouvez amener vos propres boissons et pique-niques.

                Attention, grillades interdites dans le parc.
                """,
                """
                The CinéTransat bar serves drinks only. Payment by cash, card, or Twint. No food is sold on site. You may bring your own drinks and picnics.

                Please note: barbecues are not allowed in the park.
                """
            ),
            "info_deckchairs_title": ("Location de transats", "Deck chair rental"),
            "info_deckchairs_body": (
                """
                Des transats sont disponibles à la location pour 5 CHF.- tous les jours de projection dès 19h00. Paiement cash, carte ou par Twint. Attention, le nombre de transats à la location est limité.

                Le placement dans le parc est libre. Prévoyez des vêtements chauds et une couverture, les fins de soirées peuvent être fraîches.
                """,
                """
                Deck chairs are available to rent for 5 CHF on every screening day as of 19h00. Payment by cash, card, or Twint. The number of deck chairs is limited.

                Seating in the park is open. Bring warm clothes and a blanket; evenings can get cool.
                """
            ),
            "info_transport_title": ("Accès et transports publics", "Getting there and public transport"),
            "info_transport_body": (
                """
                Lieu : parc de la Perle du Lac, rue de Lausanne, 1202 Genève.

                CinéTransat vous encourage à venir en transports publics, à pied ou à vélo.

                En tram : ligne 15, arrêt Butini. En bus : lignes 1 et 25, arrêts De-Chateaubriand ou Perle du Lac. En train : ligne Lancy-Pont-Rouge – Coppet, arrêt Genève-Sécheron. En bateau : ligne M4, arrêt De-Chateaubriand. À pied : 15 min. depuis la gare Cornavin ou 5 min. depuis les Bains des Pâquis.

                Attention ! Certains films peuvent se terminer après le départ des derniers bus ou trams.

                Pour l’accès des personnes à mobilité réduite, contactez-nous sur info@cinetransat.ch. Le chemin de la partie basse du parc est large, plat et praticable. Certains chemins intérieurs présentent des pentes de 10–12 %. Il n’y a malheureusement pas de places de stationnement dédiées à proximité directe, mais une dépose-reprise vers le Restaurant de la Perle-du-lac est possible.
                """,
                """
                Venue: La Perle du Lac park, rue de Lausanne, 1202 Geneva.

                CinéTransat encourages you to come by public transport, on foot, or by bike.

                Tram: line 15, Butini stop. Bus: lines 1 and 25, De-Chateaubriand or Perle du Lac stops. Train: Lancy-Pont-Rouge – Coppet line, Genève-Sécheron stop. Boat: M4 line, De-Chateaubriand stop. On foot: 15 min from Cornavin station or 5 min from les Bains des Pâquis.

                Please note: some films may end after the last bus or tram.

                For wheelchair access, contact us at info@cinetransat.ch. The path along the lower part of the park is wide, flat, and passable. Some inner paths have 10–12% slopes. There are no dedicated parking spaces right next to the site, but drop-off near the Restaurant de la Perle du Lac is possible.
                """
            ),
            "info_cancellations_title": ("Annulations", "Cancellations"),
            "info_cancellations_body": (
                """
                Projections annulées en cas de pluie ou de fort vent. Décision au plus tard le jour même de la projection à 19h30.

                Annonce sur la page d’accueil de ce site et sur notre page Facebook ou Instagram.

                Les notifications de mise à jour devraient apparaître dans cette app, si vous avez autorisé les notifications.
                """,
                """
                Screenings are cancelled in case of rain or strong wind. The decision is made no later than 7:30 p.m. on the day of the screening.

                Updates are posted on the homepage of this website and on our Facebook or Instagram pages.

                Update notifications should appear in this app, if you authorized notifications.
                """
            ),
            "info_toilets_title": ("Toilettes", "Toilets"),
            "info_toilets_body": (
                "Toilettes sèches à disposition sur le site de CinéTransat et WC publics situés au bas du parc, à 100 m et à 300 m avec accès chaises roulantes.",
                "Dry toilets are available on the CinéTransat site, and public restrooms at the bottom of the park, 100 m and 300 m away, with wheelchair access."
            ),
            "info_smoking_title": ("Fumée", "Smoking"),
            "info_smoking_body": (
                "Merci de ne pas jeter vos mégots dans l’herbe afin de nous aider à laisser le parc propre après les séances. Par égard pour vos voisin.e.s de pelouse, nous vous remercions de bien vouloir vous abstenir de fumer pendant le film.",
                "Please do not throw cigarette butts in the grass so we can keep the park clean after screenings. Out of consideration for others on the lawn, please refrain from smoking during the film."
            ),
            "info_waste_title": ("Déchets", "Waste"),
            "info_waste_body": (
                "Des zones de tri sont à disposition dans le parc. Merci de les utiliser après votre pique-nique pour ne rien laisser sur place à votre départ.",
                "Recycling areas are available in the park. Please use them after your picnic and take nothing away when you leave."
            ),
            "info_dogs_title": ("Chiens", "Dogs"),
            "info_dogs_body": (
                "S’il peut rester calme pendant tout le film et ne pas déranger la projection, votre animal de compagnie peut participer à la fête. Il doit être tenue en laisse. Merci pour votre compréhension.",
                "If your pet can stay calm for the whole film and not disturb the screening, they are welcome. Dogs must be kept on a leash. Thank you for your understanding."
            ),
            "info_bikes_title": ("Vélos", "Bicycles"),
            "info_bikes_body": (
                """
                Accès à vélo possible.

                Merci de ne pas attacher les vélos aux vaubans de la manifestation.
                """,
                """
                The site is accessible by bicycle.

                Please do not lock bikes to the festival barriers.
                """
            ),
            "info_accessibility_title": ("Accessibilité", "Accessibility"),
            "info_accessibility_body": (
                """
                CinéTransat est un cinéma éphémère, en extérieur, dans un parc ; les mesures d’accessibilité sont donc plus compliquées à mettre en place que dans une salle de cinéma.

                L’accès au parc par le bas de la pelouse est accessible aux personnes à mobilité réduite. Les films n’ont pas d’audio description ou de sous-titres pour malentendant (CC). Ils sont sous-titrés en français pour les films étrangers et en anglais pour les films francophones.

                Les WC avec accès chaise roulante sont en bas du parc, à 300 m vers le restaurant de la Perle du Lac. Les personnes à mobilité réduite peuvent nous contacter si elles ont besoin d’une zone dégagée en bas de la pelouse, d’assistance ou d’un transat mis de côté.

                N’hésitez pas à nous contacter en cas de question ou de besoin particulier et nous ferons au mieux pour vous accommoder : info@cinetransat.ch
                """,
                """
                CinéTransat is a temporary outdoor cinema in a park, so accessibility measures are harder to provide than in a regular theatre.

                The lower lawn entrance is accessible for people with reduced mobility. Films do not have audio description or closed captions (CC). Foreign-language films are subtitled in French; French-language films are subtitled in English.

                Wheelchair-accessible restrooms are at the bottom of the park, 300 m towards the Restaurant de la Perle du Lac. Visitors with reduced mobility can contact us for a cleared area on the lower lawn, assistance, or a reserved deck chair.

                For any questions or specific needs, contact us and we will do our best to help: info@cinetransat.ch
                """
            ),
            "settings_notifications": ("Alertes annulations", "Cancellation alerts"),
            "settings_notifications_help": (
                "Recevez une notification si une séance est annulée (pluie ou vent), même lorsque l’app est fermée.",
                "Get notified when a screening is canceled (rain or wind), even when the app is closed."
            ),
            "settings_notifications_enable": ("Activer les notifications", "Enable notifications"),
            "settings_notifications_on": ("Notifications activées", "Notifications on"),
            "settings_notifications_denied": (
                "Autorisez les notifications dans Réglages iOS pour recevoir les alertes.",
                "Allow notifications in iOS Settings to receive alerts."
            ),
            "settings_notifications_status_ready": (
                "Abonné à %@ — alertes même app fermée.",
                "Subscribed to %@ — alerts work when the app is closed."
            ),
            "settings_notifications_status_waiting_apns": (
                "En attente de l’enregistrement Apple Push…",
                "Waiting for Apple Push registration…"
            ),
            "settings_notifications_status_connecting": (
                "Connexion au service d’alertes…",
                "Connecting to alert service…"
            ),
            "settings_notifications_apns_failed": (
                "Échec Apple Push : %@",
                "Apple Push registration failed: %@"
            ),
            "settings_notifications_apns_timeout": (
                "Délai dépassé pour Apple Push. Désactivez puis réactivez les alertes. Utilisez un iPhone réel (pas le simulateur).",
                "Apple Push registration timed out. Toggle alerts off and on. Use a physical iPhone (not the Simulator)."
            ),
            "notification_cancel_title": ("Séance annulée", "Screening canceled"),
            "notification_cancel_body": (
                "%@ — %@. Séance annulée (intempéries).",
                "%@ — %@. Canceled due to weather."
            ),
        ]
        let pair = table[key] ?? (fr: key, en: key)
        switch language {
        case .fr: return pair.fr
        case .en: return pair.en
        }
    }
}

enum FestivalDateFormatters {
    private static var zurichCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        return cal
    }

    static func screeningDay(_ date: Date, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.calendar = zurichCalendar
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func screeningTime(_ date: Date, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.calendar = zurichCalendar
        formatter.locale = Locale(identifier: "en_GB_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func mediumDate(_ date: Date, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.calendar = zurichCalendar
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func posterBadgeDay(_ date: Date, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.calendar = zurichCalendar
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter.string(from: date)
    }
}

func localizedProgramTitle(year: Int, language: AppLanguage) -> String {
    "\(year)"
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

    func localizedSynopsis(language: AppLanguage) -> String {
        switch language {
        case .fr:
            return synopsis
        case .en:
            if let synopsisEn, !synopsisEn.isEmpty { return synopsisEn }
            return synopsis
        }
    }

    var releaseYear: Int? {
        PosterCatalog.releaseYear(forPosterKey: posterKey)
    }
}
