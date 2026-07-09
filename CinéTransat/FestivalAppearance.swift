//
//  FestivalAppearance.swift
//  CinéTransat
//

import SwiftUI
import UIKit

enum FestivalAppearance {
    static func configure() {
        let navy = UIColor.festivalProgramBackground
        let pink = UIColor.festivalAccent
        let light = UIColor.festivalProgramTitle

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = navy
        tab.shadowColor = UIColor.black.withAlphaComponent(0.22)

        for layout in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            layout.normal.iconColor = pink
            layout.normal.titleTextAttributes = [.foregroundColor: pink]
            layout.selected.iconColor = light
            layout.selected.titleTextAttributes = [.foregroundColor: light]
        }

        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITabBar.appearance().tintColor = light
        UITabBar.appearance().unselectedItemTintColor = pink

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = navy
        nav.shadowColor = UIColor.white.withAlphaComponent(0.08)
        nav.titleTextAttributes = [.foregroundColor: light]
        nav.largeTitleTextAttributes = [.foregroundColor: light]

        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().tintColor = pink

        UITableView.appearance().backgroundColor = navy
        UITableViewCell.appearance().backgroundColor = .clear
        UICollectionView.appearance().backgroundColor = navy

        let segmentTrack = UIColor.festivalProgramPagerTrack
        UISegmentedControl.appearance().backgroundColor = segmentTrack
        UISegmentedControl.appearance().selectedSegmentTintColor = pink
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: pink],
            for: .normal
        )
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: light],
            for: .selected
        )

        UISwitch.appearance().onTintColor = pink
        UISwitch.appearance().tintColor = UIColor.festivalProgramPagerTrack
    }
}

// MARK: - View chrome

private struct FestivalScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            Color.festivalProgramBackground.ignoresSafeArea()
            content
        }
    }
}

extension View {
    func festivalScreenBackground() -> some View {
        modifier(FestivalScreenBackground())
    }

    func festivalListChrome() -> some View {
        scrollContentBackground(.hidden)
            .listStyle(.plain)
            .listRowSeparatorTint(Color.white.opacity(0.12))
            .listRowBackground(Color.white.opacity(0.08))
    }

    func festivalWatchListChrome() -> some View {
        scrollContentBackground(.hidden)
            .listStyle(.plain)
            .listRowSeparatorTint(Color.festivalAccent.opacity(0.22))
            .listRowBackground(Color.festivalProgramBackground)
    }

    func festivalSettingsListChrome() -> some View {
        scrollContentBackground(.hidden)
            .listStyle(.plain)
            .listRowSeparatorTint(Color.festivalAccent.opacity(0.22))
            .listRowBackground(Color.festivalProgramBackground)
            .listSectionSeparatorTint(Color.festivalAccent.opacity(0.15))
            .background(Color.festivalProgramBackground)
            .foregroundStyle(Color.festivalAccent)
            .tint(Color.festivalAccent)
    }

    func festivalPinkNavigationTitle(_ title: String) -> some View {
        toolbar {
            ToolbarItem(placement: .principal) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.festivalAccent)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
    }

    func festivalCardChrome() -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            }
    }
}
