//
//  RattrapageVotesStore.swift
//  CinéTransat
//
//  Soirée Rattrapage votes live on each screening inside seasons/{year}:
//  weeks[i].screenings[j].votes = [anonymousDeviceUuid, …]
//

import Combine
import Foundation
import OSLog

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class RattrapageVotesStore: ObservableObject {
    private static let logger = Logger(subsystem: "com.heewhack.CineTransat", category: "RattrapageVotes")

    /// Screening day keys this install has voted for (optimistic + season listener).
    @Published private(set) var votedScreeningIDs: Set<String> = []
    /// Vote tallies per screening (device UUID count on each screening’s `votes` array).
    @Published private(set) var voteCountByScreeningID: [String: Int] = [:]

    #if canImport(FirebaseFirestore)
    private lazy var db = Firestore.firestore()
    private var seasonListener: ListenerRegistration?
    private var observedSeasonYear: Int?
    private var observedScreeningIDs: Set<String> = []
    #endif

    func hasVoted(screeningId: String) -> Bool {
        votedScreeningIDs.contains(screeningId)
    }

    func voteCount(screeningId: String) -> Int {
        voteCountByScreeningID[screeningId] ?? 0
    }

    /// Share of all votes cast across observed options (0…1). Sums to ~1 like a bar graph.
    func voteShare(screeningId: String) -> Double {
        let total = voteCountByScreeningID.values.reduce(0, +)
        guard total > 0 else { return 0 }
        return Double(voteCount(screeningId: screeningId)) / Double(total)
    }

    var totalVoteCount: Int {
        voteCountByScreeningID.values.reduce(0, +)
    }

    func startObserving(screeningIds: [String], seasonYear: Int) {
        guard !AppStoreScreenshotConfiguration.isActive else { return }
        #if canImport(FirebaseFirestore)
        let wanted = Set(screeningIds)
        if observedSeasonYear == seasonYear, observedScreeningIDs == wanted, seasonListener != nil {
            return
        }

        observedSeasonYear = seasonYear
        observedScreeningIDs = wanted
        votedScreeningIDs = votedScreeningIDs.intersection(wanted)
        voteCountByScreeningID = voteCountByScreeningID.filter { wanted.contains($0.key) }
        for id in wanted where voteCountByScreeningID[id] == nil {
            voteCountByScreeningID[id] = 0
        }

        seasonListener?.remove()
        let ref = db.document(FirestorePaths.season(seasonYear))
        seasonListener = ref.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    Self.logger.error("Season votes listener: \(error.localizedDescription)")
                    return
                }
                guard let data = snapshot?.data() else { return }
                self.applyVotes(from: data, deviceId: AnonymousDeviceIdentity.deviceID)
            }
        }
        #endif
    }

    func stopAllObservations() {
        #if canImport(FirebaseFirestore)
        seasonListener?.remove()
        seasonListener = nil
        observedSeasonYear = nil
        observedScreeningIDs = []
        #endif
    }

    func toggleVote(screeningId: String, seasonYear: Int) {
        guard !AppStoreScreenshotConfiguration.isActive else { return }
        let currentlyVoted = votedScreeningIDs.contains(screeningId)
        if currentlyVoted {
            votedScreeningIDs.remove(screeningId)
            voteCountByScreeningID[screeningId] = max(0, voteCount(screeningId: screeningId) - 1)
        } else {
            votedScreeningIDs.insert(screeningId)
            voteCountByScreeningID[screeningId] = voteCount(screeningId: screeningId) + 1
        }
        Task {
            let success = await writeVote(
                screeningId: screeningId,
                seasonYear: seasonYear,
                add: !currentlyVoted
            )
            if !success {
                if currentlyVoted {
                    votedScreeningIDs.insert(screeningId)
                    voteCountByScreeningID[screeningId] = voteCount(screeningId: screeningId) + 1
                } else {
                    votedScreeningIDs.remove(screeningId)
                    voteCountByScreeningID[screeningId] = max(0, voteCount(screeningId: screeningId) - 1)
                }
            }
        }
    }

    #if canImport(FirebaseFirestore)
    private func applyVotes(from seasonData: [String: Any], deviceId: String) {
        var nextVoted: Set<String> = []
        var nextCounts: [String: Int] = [:]
        for id in observedScreeningIDs {
            nextCounts[id] = 0
        }
        for screening in Self.screenings(in: seasonData) {
            guard let id = screening["id"] as? String, observedScreeningIDs.contains(id) else { continue }
            let votes = screening["votes"] as? [String] ?? []
            nextCounts[id] = votes.count
            if votes.contains(deviceId) {
                nextVoted.insert(id)
            }
        }
        votedScreeningIDs = nextVoted
        voteCountByScreeningID = nextCounts
    }

    private func writeVote(screeningId: String, seasonYear: Int, add: Bool) async -> Bool {
        let deviceId = AnonymousDeviceIdentity.deviceID
        let ref = db.document(FirestorePaths.season(seasonYear))
        do {
            _ = try await db.runTransaction { transaction, errorPointer -> Any? in
                let snap: DocumentSnapshot
                do {
                    snap = try transaction.getDocument(ref)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
                guard var data = snap.data() else {
                    errorPointer?.pointee = NSError(
                        domain: "CineTransat.RattrapageVotes",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Missing season document"]
                    )
                    return nil
                }
                guard Self.applyVoteMutation(
                    to: &data,
                    screeningId: screeningId,
                    deviceId: deviceId,
                    add: add
                ) else {
                    errorPointer?.pointee = NSError(
                        domain: "CineTransat.RattrapageVotes",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Screening \(screeningId) not found"]
                    )
                    return nil
                }
                transaction.setData(data, forDocument: ref)
                return true
            }
            Self.logger.info(
                "Vote \(add ? "+" : "−") for \(screeningId) on seasons/\(seasonYear) (…\(deviceId.suffix(6)))"
            )
            return true
        } catch {
            Self.logger.error("Vote write failed \(screeningId): \(error.localizedDescription)")
            return false
        }
    }

    /// Mutates `weeks[*].screenings[*].votes` for the matching screening id. Returns false if not found.
    private static func applyVoteMutation(
        to seasonData: inout [String: Any],
        screeningId: String,
        deviceId: String,
        add: Bool
    ) -> Bool {
        guard let weeksAny = seasonData["weeks"] as? [Any] else { return false }
        var weeks: [[String: Any]] = weeksAny.compactMap { deepStringKeyedDictionary($0) }
        guard weeks.count == weeksAny.count else { return false }

        var found = false
        for weekIndex in weeks.indices {
            guard let screeningsAny = weeks[weekIndex]["screenings"] as? [Any] else { continue }
            var screenings: [[String: Any]] = screeningsAny.compactMap { deepStringKeyedDictionary($0) }
            guard screenings.count == screeningsAny.count else { continue }

            for screeningIndex in screenings.indices {
                guard screenings[screeningIndex]["id"] as? String == screeningId else { continue }
                var votes = screenings[screeningIndex]["votes"] as? [String] ?? []
                if add {
                    if !votes.contains(deviceId) {
                        votes.append(deviceId)
                    }
                } else {
                    votes.removeAll { $0 == deviceId }
                }
                screenings[screeningIndex]["votes"] = votes
                weeks[weekIndex]["screenings"] = screenings
                found = true
                break
            }
            if found { break }
        }
        guard found else { return false }
        seasonData["weeks"] = weeks
        return true
    }

    private static func screenings(in seasonData: [String: Any]) -> [[String: Any]] {
        guard let weeksAny = seasonData["weeks"] as? [Any] else { return [] }
        return weeksAny.compactMap { deepStringKeyedDictionary($0) }.flatMap { week -> [[String: Any]] in
            guard let screeningsAny = week["screenings"] as? [Any] else { return [] }
            return screeningsAny.compactMap { deepStringKeyedDictionary($0) }
        }
    }

    private static func deepStringKeyedDictionary(_ value: Any) -> [String: Any]? {
        guard let dict = value as? [String: Any] else { return nil }
        var out: [String: Any] = [:]
        for (key, nested) in dict {
            if let nestedDict = nested as? [String: Any] {
                out[key] = deepStringKeyedDictionary(nestedDict) ?? nestedDict
            } else if let nestedArray = nested as? [Any] {
                out[key] = nestedArray.map { item -> Any in
                    deepStringKeyedDictionary(item) ?? item
                }
            } else {
                out[key] = nested
            }
        }
        return out
    }
    #else
    private func writeVote(screeningId: String, seasonYear: Int, add: Bool) async -> Bool {
        true
    }
    #endif
}
