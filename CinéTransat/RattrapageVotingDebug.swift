//
//  RattrapageVotingDebug.swift
//  CinéTransat
//
//  TEMPORARY — enable pretend cancellations / Rattrapage host for local voting UI tests.
//  Set `isEnabled` to false (or delete this file’s usages) before release.
//

import Foundation

enum RattrapageVotingDebug {
    /// Flip to `true` only for local UI tests (fake cancellations / Rattrapage host).
    static let isEnabled = false

    /// Week 1 (9–12 Jul) + Thu 16 Jul — treated as canceled for the Rattrapage poll list.
    static let pretendCanceledIDs: Set<String> = [
        "20260709",
        "20260710",
        "20260711",
        "20260712",
        "20260716",
    ]

    /// 2026 has no Soirée Rattrapage yet — temporarily host the poll on courts-métrages.
    static let pretendRattrapageScreeningID = "20260719"

    static func isPretendCanceled(_ screeningID: String) -> Bool {
        isEnabled && pretendCanceledIDs.contains(screeningID)
    }

    static func isPretendRattrapage(_ screeningID: String) -> Bool {
        isEnabled && screeningID == pretendRattrapageScreeningID
    }
}
