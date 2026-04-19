//
//  UsefulInfoView.swift
//  CinéTransat
//

import SwiftUI

struct UsefulInfoView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(PracticalInfoSection.all) { section in
                        DisclosureGroup {
                            section.content
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
            .navigationTitle("Infos pratiques")
        }
    }
}

// MARK: - Sections (aligned with https://www.cinetransat.ch/infos-pratiques )

private struct PracticalInfoSection: Identifiable {
    var id: String { title }
    let title: String
    let icon: String
    let content: Text

    private static var seasonYear: String { "\(FestivalProgramData.demoYear)" }

    static let all: [PracticalInfoSection] = [
        PracticalInfoSection(
            title: "Projections gratuites",
            icon: "gift.fill",
            content: Text(
                """
                Les projections de CinéTransat ont lieu dans le parc public de la Perle du Lac à Genève, et sont gratuites. Elles sont accessibles à tou.te.s et sans réservation !
                """
            )
        ),
        PracticalInfoSection(
            title: "Jours et horaires",
            icon: "calendar",
            content: Text(
                """
                Projections du jeudi au dimanche, du 10 juillet au 17 août \(seasonYear).

                Début des films à la tombée de la nuit, entre 22h00 (mi-juillet) et 21h15 (fin août).

                Buvette, location de transats et animations dès 19h00.

                Fin de la soirée vers minuit.
                """
            )
        ),
        PracticalInfoSection(
            title: "Âge légal",
            icon: "person.crop.circle.badge.questionmark",
            content: Text(
                """
                L’âge légal pour le visionnage des films varie de 7 à 16 ans.

                Merci de respecter ces consignes et de ne pas venir avec des enfants plus jeunes que l’âge légal indiqué. Des contrôles pourront être effectués par la Brigade des mineurs.
                """
            )
        ),
        PracticalInfoSection(
            title: "Langues et sous-titres",
            icon: "captions.bubble.fill",
            content: Text(
                """
                Les films sont diffusés en version originale afin de préserver au mieux la qualité de l’œuvre et son empreinte culturelle. Genève étant une ville internationale, il nous tient à cœur de toucher tous les publics et communautés représentés.

                De manière générale, les films en français sont sous-titrés en anglais ; tous les autres films sont sous-titrés en français.

                Les langues et les sous-titres sont indiqués dans le programme.
                """
            )
        ),
        PracticalInfoSection(
            title: "Buvette et pique-niques",
            icon: "cup.and.saucer.fill",
            content: Text(
                """
                La buvette CinéTransat proposent des boissons uniquement. Paiement cash, carte et par Twint. Pas de vente de nourriture sur place. Vous pouvez amener vos propres boissons et pique-niques.

                Attention, grillades interdites dans le parc.
                """
            )
        ),
        PracticalInfoSection(
            title: "Location de transats",
            icon: "chair.lounge.fill",
            content: Text(
                """
                Des transats sont disponibles à la location pour CHF 5.- tous les jours de projection dès 19h00. Paiement cash, carte ou par Twint. Attention, le nombre de transats à la location est limité.

                Le placement dans le parc est libre. Prévoyez des vêtements chauds et une couverture, les fins de soirées peuvent être fraîches.
                """
            )
        ),
        PracticalInfoSection(
            title: "Accès et transports publics",
            icon: "tram.fill",
            content: Text(
                """
                Lieu : parc de la Perle du Lac, rue de Lausanne, 1202 Genève.

                CinéTransat vous encourage à venir en transports publics, à pied ou à vélo.

                En tram : ligne 15, arrêt Butini. En bus : lignes 1 et 25, arrêts De-Chateaubriand ou Perle du Lac. En train : ligne Lancy-Pont-Rouge – Coppet, arrêt Genève-Sécheron. En bateau : ligne M4, arrêt De-Chateaubriand. À pied : 15 min. depuis la gare Cornavin ou 5 min. depuis les Bains des Pâquis.

                Attention ! Certains films peuvent se terminer après le départ des derniers bus ou trams.

                Pour l’accès des personnes à mobilité réduite, contactez-nous sur info@cinetransat.ch. Le chemin de la partie basse du parc est large, plat et praticable. Certains chemins intérieurs présentent des pentes de 10–12 %. Il n’y a malheureusement pas de places de stationnement dédiées à proximité directe, mais une dépose-reprise vers le Restaurant de la Perle-du-lac est possible.
                """
            )
        ),
        PracticalInfoSection(
            title: "Annulations",
            icon: "cloud.bolt.rain.fill",
            content: Text(
                """
                Projections annulées en cas de pluie ou de fort vent. Décision au plus tard le jour même de la projection à 19h30.

                Annonce sur la page d’accueil de ce site et sur notre page Facebook ou Instagram.
                """
            )
        ),
        PracticalInfoSection(
            title: "Toilettes",
            icon: "toilet.fill",
            content: Text(
                """
                Toilettes sèches à disposition sur le site de CinéTransat et WC publics situés au bas du parc, à 100 m et à 300 m avec accès chaises roulantes.
                """
            )
        ),
        PracticalInfoSection(
            title: "Fumée",
            icon: "smoke.fill",
            content: Text(
                """
                Merci de ne pas jeter vos mégots dans l’herbe afin de nous aider à laisser le parc propre après les séances. Par égard pour vos voisin.e.s de pelouse, nous vous remercions de bien vouloir vous abstenir de fumer pendant le film.
                """
            )
        ),
        PracticalInfoSection(
            title: "Déchets",
            icon: "trash.fill",
            content: Text(
                """
                Des zones de tri sont à disposition dans le parc. Merci de les utiliser après votre pique-nique pour ne rien laisser sur place à votre départ.
                """
            )
        ),
        PracticalInfoSection(
            title: "Chiens",
            icon: "pawprint.fill",
            content: Text(
                """
                S’il peut rester calme pendant tout le film et ne pas déranger la projection, votre animal de compagnie peut participer à la fête. Il doit être tenue en laisse. Merci pour votre compréhension.
                """
            )
        ),
        PracticalInfoSection(
            title: "Vélos",
            icon: "bicycle",
            content: Text(
                """
                Accès à vélo possible.

                Merci de ne pas attacher les vélos aux vaubans de la manifestation.
                """
            )
        ),
        PracticalInfoSection(
            title: "Accessibilité",
            icon: "figure.roll",
            content: Text(
                """
                CinéTransat est un cinéma éphémère, en extérieur, dans un parc ; les mesures d’accessibilité sont donc plus compliquées à mettre en place que dans une salle de cinéma.

                L’accès au parc par le bas de la pelouse est accessible aux personnes à mobilité réduite. Les films n’ont pas d’audio description ou de sous-titres pour malentendant (CC). Ils sont sous-titrés en français pour les films étrangers et en anglais pour les films francophones.

                Les WC avec accès chaise roulante sont en bas du parc, à 300 m vers le restaurant de la Perle du Lac. Les personnes à mobilité réduite peuvent nous contacter si elles ont besoin d’une zone dégagée en bas de la pelouse, d’assistance ou d’un transat mis de côté.

                N’hésitez pas à nous contacter en cas de question ou de besoin particulier et nous ferons au mieux pour vous accommoder : info@cinetransat.ch
                """
            )
        ),
    ]
}

#Preview {
    UsefulInfoView()
}
