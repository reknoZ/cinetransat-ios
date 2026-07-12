//
//  TodayTabView.swift
//  CinéTransat
//

import SwiftUI

/// First tab when there is a screening today — full movie detail for today's film(s).
struct TodayTabView: View {
    @EnvironmentObject private var program: FestivalProgramStore

    private var todayScreenings: [Screening] {
        program.allScreenings.screeningsToday()
    }

    var body: some View {
        if let first = todayScreenings.first {
            NavigationStack {
                MovieDetailView(screening: first, lineupScope: .todayOnly)
            }
        }
    }
}

#Preview {
    TodayTabView()
        .environmentObject(FestivalProgramStore.preview)
        .environmentObject(WatchListStore.preview(statsStore: WatchListStatsStore()))
        .environmentObject(WatchListStatsStore())
}
