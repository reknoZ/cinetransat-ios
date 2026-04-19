//
//  Cine_TransatApp.swift
//  CinéTransat
//
//  Created by David on 4/18/26.
//

import SwiftUI

@main
struct Cine_TransatApp: App {
    @StateObject private var watchListStore = WatchListStore()

    var body: some Scene {
        WindowGroup {
            RootWithLaunchSplash()
                .environmentObject(watchListStore)
        }
    }
}

private struct RootWithLaunchSplash: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            ContentView()
                .opacity(showSplash ? 0 : 1)

            if showSplash {
                FestivalLaunchSplashView {
                    withAnimation(.easeOut(duration: 0.32)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }
}
