//
//  FestivalColors.swift
//  CinéTransat
//

import SwiftUI
import UIKit

extension Color {
    /// Programme tab background — warm cream (light) / warm charcoal (dark).
    static let festivalProgramBackground = Color(uiColor: .festivalProgramBackground)

    /// Film titles and week labels on the programme background.
    static let festivalProgramTitle = Color(uiColor: .festivalProgramTitle)

    /// Passed screenings and de-emphasized programme text.
    static let festivalProgramTitleMuted = Color(uiColor: .festivalProgramTitleMuted)

    /// Week pager track behind the dot indicators.
    static let festivalProgramPagerTrack = Color(uiColor: .festivalProgramPagerTrack)
}

private extension UIColor {
    static let festivalProgramBackground = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.13, blue: 0.11, alpha: 1)
            : UIColor(red: 254 / 255, green: 249 / 255, blue: 226 / 255, alpha: 1)
    }

    static let festivalProgramTitle = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.96, alpha: 1)
            : UIColor(white: 0.08, alpha: 1)
    }

    static let festivalProgramTitleMuted = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.68, alpha: 1)
            : UIColor(white: 0.38, alpha: 1)
    }

    static let festivalProgramPagerTrack = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.22, alpha: 1)
            : UIColor(red: 0.86, green: 0.87, blue: 0.89, alpha: 1)
    }
}
