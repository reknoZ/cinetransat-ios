//
//  PosterKey.swift
//  CinéTransat
//

import Foundation

/// Stable poster file id (HTTPS hosting / bundled assets), usually derived from the film title.
enum PosterKey {
    /// e.g. `"Paddington 2"` → `"paddington-2"`
    static func slug(from title: String) -> String {
        let folded = title
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
        var slug = ""
        var lastWasHyphen = false
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                slug.unicodeScalars.append(scalar)
                lastWasHyphen = false
            } else if !lastWasHyphen, !slug.isEmpty {
                slug.append("-")
                lastWasHyphen = true
            }
        }
        if slug.hasSuffix("-") {
            slug.removeLast()
        }
        return slug.isEmpty ? "unknown" : slug
    }
}
