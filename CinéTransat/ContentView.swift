//
//  ContentView.swift
//  CinéTransat
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ProgramRootView()
                .tabItem {
                    Label("Programme", systemImage: "calendar")
                }

            WatchListView()
                .tabItem {
                    Label("Watch List", systemImage: "bookmark.fill")
                }

            UsefulInfoView()
                .tabItem {
                    Label("Infos", systemImage: "info.circle.fill")
                }

            AboutFestivalView()
                .tabItem {
                    Label("Festival", systemImage: "sparkles")
                }
        }
    }
}

private struct AboutFestivalView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("CinéTransat")
                        .font(.largeTitle.weight(.bold))
                    Text("Six semaines, quatre soirs par semaine : cinéma en plein air après le coucher du soleil.")
                        .font(.body)
                    Text("Les données affichées reprennent un programme type (saison \(FestivalProgramData.demoYear)) pour le développement : remplacez-les par votre JSON ou votre CMS lorsque le programme officiel est prêt.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Affiches : ajoutez au catalogue d’assets un jeu d’images par soirée, nommé exactement comme la date de la séance au format AAAAMMJJ (ex. 20250710). Tant qu’une image n’existe pas, l’app affiche le fond générique.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("À propos")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchListStore())
}
