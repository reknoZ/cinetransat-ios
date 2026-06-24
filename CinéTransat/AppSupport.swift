//
//  AppSupport.swift
//  CinéTransat
//

import Foundation
import UIKit

enum AppSupport {
    /// In-app feedback and bug reports (not the festival programme contact).
    static let feedbackEmail = "feedback@heewhack.com"

    static func feedbackMailSubject(language: AppLanguage) -> String {
        L10n.text("settings_feedback_subject", language: language)
    }

    static func feedbackMailBody(seasonYear: Int) -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let ios = UIDevice.current.systemVersion
        let model = UIDevice.current.model

        return """



        ---
        CinéTransat \(version) (\(build))
        iOS \(ios) · \(model)
        Season \(seasonYear)
        """
    }

    static func feedbackMailtoURL(language: AppLanguage, seasonYear: Int) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = feedbackEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: feedbackMailSubject(language: language)),
            URLQueryItem(name: "body", value: feedbackMailBody(seasonYear: seasonYear)),
        ]
        return components.url
    }
}
