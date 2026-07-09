//
//  FestivalColors.swift
//  CinéTransat
//
//  2026 brand palette — navy `RGB(25, 43, 89)` and pink `RGB(200, 109, 144)`.
//

import SwiftUI
import UIKit

extension Color {
    /// Programme / splash background — `#192B59`.
    static let festivalProgramBackground = Color(uiColor: .festivalProgramBackground)

    /// Primary text on programme screens (on navy background).
    static let festivalProgramTitle = Color(uiColor: .festivalProgramTitle)

    /// Passed / de-emphasized programme text.
    static let festivalProgramTitleMuted = Color(uiColor: .festivalProgramTitleMuted)

    /// Week pager track.
    static let festivalProgramPagerTrack = Color(uiColor: .festivalProgramPagerTrack)

    /// Brand accent — headings, tabs, selection — `#C86D90`.
    static let festivalAccent = Color(uiColor: .festivalAccent)

    /// Tab bar background — same navy as programme screens.
    static let festivalTabBarBackground = Color(uiColor: .festivalTabBarBackground)
}

extension UIColor {
    // MARK: - 2026 CinéTransat

    static let festivalProgramBackground = UIColor { _ in
        UIColor(red: 25 / 255, green: 43 / 255, blue: 89 / 255, alpha: 1)
    }

    static let festivalProgramTitle = UIColor { _ in
        UIColor(red: 255 / 255, green: 248 / 255, blue: 250 / 255, alpha: 1)
    }

    static let festivalProgramTitleMuted = UIColor { _ in
        UIColor(red: 176 / 255, green: 184 / 255, blue: 204 / 255, alpha: 1)
    }

    static let festivalProgramPagerTrack = UIColor { _ in
        UIColor(red: 38 / 255, green: 58 / 255, blue: 108 / 255, alpha: 1)
    }

    static let festivalAccent = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 220 / 255, green: 130 / 255, blue: 165 / 255, alpha: 1)
            : UIColor(red: 200 / 255, green: 109 / 255, blue: 144 / 255, alpha: 1)
    }

    static var festivalTabBarBackground: UIColor { festivalProgramBackground }
}
