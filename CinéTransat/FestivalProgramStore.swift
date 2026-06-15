//
//  FestivalProgramStore.swift
//  CinéTransat
//

import Foundation
import SwiftUI
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Live festival data from **Cloud Firestore**, with bundled fallback when offline.
@MainActor
final class FestivalProgramStore: ObservableObject {
    enum DataSource: String {
        case bundled
        case firestore
        case cache
    }

    @Published private(set) var weeks: [FestivalWeek] = FestivalProgramBootstrap.weeks
    @Published private(set) var seasonYear: Int = FestivalPublicConfig.currentSeasonYear
    @Published private(set) var publicConfig: FestivalPublicConfig = .defaults
    /// All season years in Firestore (`seasons` collection), newest first.
    @Published private(set) var availableSeasonYears: [Int] = FestivalProgramStore.defaultAvailableSeasonYears
    @Published private(set) var source: DataSource = .bundled
    @Published private(set) var lastUpdatedAt: Date?
    @Published private(set) var lastErrorMessage: String?
    /// Full-screen progress after splash while poster images are fetched.
    @Published private(set) var isPrefetchingPosters = false
    /// Bumped after a poster-only pull-to-refresh so on-screen cells retry downloads.
    @Published private(set) var posterRefreshGeneration: UInt = 0

    var allScreenings: [Screening] {
        weeks.flatMap(\.orderedScreenings)
    }

    /// Newest `seasons/{year}` document in Firestore (fallback: config or app default).
    var latestSeasonYear: Int {
        availableSeasonYears.max() ?? publicConfig.currentSeasonYear
    }

    /// Watch list adds are limited to the active season once films are announced.
    func canAddToWatchList(_ screening: Screening) -> Bool {
        seasonYear == publicConfig.currentSeasonYear && screening.isProgramAnnounced
    }

    /// Offline / pre-Firestore catalogue (newest first). Replaced when `seasons` is loaded.
    static let defaultAvailableSeasonYears: [Int] = {
        var years = [FestivalPublicConfig.currentSeasonYear, 2025]
        var seen = Set<Int>()
        return years.filter { seen.insert($0).inserted }.sorted(by: >)
    }()

    #if canImport(FirebaseFirestore)
    private lazy var db = Firestore.firestore()
    private var configListener: ListenerRegistration?
    private var seasonListener: ListenerRegistration?
    private var listeningSeasonYear: Int?
    #endif

    init(startListeners: Bool = false) {
        if startListeners {
            loadCachedSeasonIfAvailable(year: FestivalPublicConfig.currentSeasonYear)
            startListening()
        }
    }

    /// Bundled programme only — for App Store screenshots (no Firestore / splash).
    func prepareBundledDataForScreenshots() {
        weeks = FestivalProgramBootstrap.weeks
        seasonYear = FestivalProgramBootstrap.seasonYear
        availableSeasonYears = [FestivalProgramBootstrap.seasonYear]
        publicConfig = FestivalPublicConfig(
            currentSeasonYear: FestivalProgramBootstrap.seasonYear,
            websiteURL: FestivalPublicConfig.defaults.websiteURL,
            practicalInfoURL: FestivalPublicConfig.defaults.practicalInfoURL,
            contactEmail: FestivalPublicConfig.defaults.contactEmail,
            facebookURL: FestivalPublicConfig.defaults.facebookURL,
            instagramURL: FestivalPublicConfig.defaults.instagramURL,
            posterBaseURL: FestivalPublicConfig.defaults.posterBaseURL
        )
        source = .bundled
        lastErrorMessage = nil
        lastUpdatedAt = nil
        isPrefetchingPosters = false
    }

    /// Called once the launch splash animation has finished — network and poster downloads start here.
    func completePostLaunchSetup() async {
        isPrefetchingPosters = true
        defer { isPrefetchingPosters = false }

        startListening()
        await refreshSeasonCatalogIfNeeded()
        selectSeason(year: latestSeasonYear)
        await prefetchPostersForCurrentSeason()
        await CancellationNotificationManager.shared.refreshAuthorizationStatus()
        await CancellationNotificationManager.shared.syncSubscriptionIfNeeded(
            seasonYear: publicConfig.currentSeasonYear
        )
    }

    /// Re-downloads posters for the given keys (or the whole season if `posterKeys` is nil).
    /// Skips disk cache so Hosting updates replace test duplicates and revised JPGs.
    @discardableResult
    func refreshMissingPosters(for posterKeys: Set<String>? = nil) async -> Int {
        let count = await prefetchPostersForCurrentSeason(
            forceNetwork: true,
            includeCachedOnDisk: false,
            posterKeysFilter: posterKeys
        )
        posterRefreshGeneration &+= 1
        return count
    }

    @discardableResult
    func prefetchPostersForCurrentSeason(
        forceNetwork: Bool = false,
        includeCachedOnDisk: Bool = true,
        posterKeysFilter: Set<String>? = nil
    ) async -> Int {
        let template = publicConfig.posterBaseURL
        guard let template, !template.isEmpty else {
            #if DEBUG
            print("Poster prefetch skipped: posterBaseURL is missing in Firestore publicConfig")
            #endif
            return 0
        }

        var pending: [(posterKey: String, urls: [URL])] = []
        var seenKeys = Set<String>()

        for screening in allScreenings where !screening.usesTBDPlaceholderPoster {
            guard seenKeys.insert(screening.posterKey).inserted else { continue }
            if let posterKeysFilter, !posterKeysFilter.contains(screening.posterKey) {
                continue
            }
            if includeCachedOnDisk,
               PosterImageCache.shared.cachedImageIfPresent(posterKey: screening.posterKey) != nil {
                continue
            }
            let urls = screening.remotePosterURLs(posterBaseURLTemplate: template)
            guard !urls.isEmpty else { continue }
            pending.append((screening.posterKey, urls))
        }

        var downloaded = 0
        for item in pending {
            if forceNetwork {
                PosterImageCache.shared.clearURLCache(for: item.urls)
            }
            if await PosterImageCache.shared.image(
                posterKey: item.posterKey,
                remoteURLs: item.urls,
                forceNetwork: forceNetwork
            ) != nil {
                downloaded += 1
            }
        }
        #if DEBUG
        print("Poster prefetch: \(downloaded)/\(pending.count) downloaded (forceNetwork=\(forceNetwork))")
        #endif
        return downloaded
    }

    deinit {
        #if canImport(FirebaseFirestore)
        configListener?.remove()
        seasonListener?.remove()
        #endif
    }

    func startListening() {
        #if canImport(FirebaseFirestore)
        configListener?.remove()
        configListener = db.document(FirestorePaths.publicConfig).addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    self.lastErrorMessage = error.localizedDescription
                    return
                }
                guard let data = snapshot?.data() else { return }
                self.applyPublicConfigDocument(data)
                Task { await self.refreshSeasonCatalog() }
                if self.listeningSeasonYear == nil {
                    let year = self.latestSeasonYear
                    self.seasonYear = year
                    self.loadCachedSeasonIfAvailable(year: year)
                    self.attachSeasonListener(year: year)
                }
            }
        }

        #endif
    }

    /// Fills `availableSeasonYears` (not needed for first paint — call from refresh if needed).
    func refreshSeasonCatalogIfNeeded() async {
        #if canImport(FirebaseFirestore)
        await refreshSeasonCatalog()
        #endif
    }

    func selectSeason(year: Int) {
        guard seasonYear != year else { return }
        seasonYear = year
        loadCachedSeasonIfAvailable(year: year)
        #if canImport(FirebaseFirestore)
        attachSeasonListener(year: year)
        #endif
    }

    func refreshFromServer() async {
        #if canImport(FirebaseFirestore)
        do {
            let config = try await db.document(FirestorePaths.publicConfig).getDocument()
            if let data = config.data() {
                applyPublicConfigDocument(data)
            }

            let year = publicConfig.currentSeasonYear
            let seasonSnap = try await db.document(FirestorePaths.season(year)).getDocument()
            if let data = seasonSnap.data() {
                applyProgramDocument(data, source: .firestore, expectedYear: year)
                cacheProgramDocument(data, year: year)
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
        #endif
    }

    func exportProgramSeedJSONData() throws -> Data {
        try FestivalProgramBootstrap.exportProgramDocumentJSONData(
            weeks: weeks,
            seasonYear: seasonYear
        )
    }

    // MARK: - Firestore listeners

    #if canImport(FirebaseFirestore)
    private func attachSeasonListener(year: Int) {
        guard listeningSeasonYear != year else { return }
        seasonListener?.remove()
        listeningSeasonYear = year

        seasonListener = db.document(FirestorePaths.season(year)).addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    self.lastErrorMessage = error.localizedDescription
                    return
                }
                guard let data = snapshot?.data() else { return }
                self.applyProgramDocument(data, source: .firestore, expectedYear: year)
                self.cacheProgramDocument(data, year: year)
            }
        }
    }

    private func refreshSeasonCatalog() async {
        do {
            let snapshot = try await db.collection(FirestorePaths.seasonsCollection).getDocuments()
            let years = snapshot.documents.compactMap { Int($0.documentID) }.sorted(by: >)
            if !years.isEmpty {
                availableSeasonYears = years
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
    #endif

    // MARK: - Apply Firestore payloads

    private func applyProgramDocument(_ data: [String: Any], source: DataSource, expectedYear: Int) {
        do {
            let payload = try JSONSerialization.data(withJSONObject: data)
            let decoded = try FestivalProgramFeedDecoder.decodeProgram(from: payload)

            #if canImport(FirebaseFirestore)
            if source == .firestore {
                processNewlyCanceledScreenings(from: decoded)
            }
            #endif

            weeks = decoded.weeks
            seasonYear = decoded.seasonYear
            if seasonYear != expectedYear {
                lastErrorMessage = "Season document year \(decoded.seasonYear) does not match id \(expectedYear)."
            } else {
                lastErrorMessage = nil
            }
            self.source = source
            lastUpdatedAt = Date()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    #if canImport(FirebaseFirestore)
    private static let knownCanceledIDsKey = "knownCanceledScreeningIDs"

    /// Tracks screening IDs we have already alerted for (persists across launches).
    private func knownCanceledScreeningIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.knownCanceledIDsKey) ?? [])
    }

    private func saveKnownCanceledScreeningIDs(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: Self.knownCanceledIDsKey)
    }

    private func processNewlyCanceledScreenings(from decoded: (seasonYear: Int, weeks: [FestivalWeek])) {
        let canceledNow = decoded.weeks
            .flatMap(\.orderedScreenings)
            .filter(\.isCanceled)
        let canceledIDsNow = Set(canceledNow.map(\.id))
        let known = knownCanceledScreeningIDs()

        if known.isEmpty {
            // First run: record current state without alerting for films already canceled in Firestore.
            saveKnownCanceledScreeningIDs(canceledIDsNow)
            return
        }

        let newlyCanceled = canceledNow.filter { !known.contains($0.id) }
        if !newlyCanceled.isEmpty {
            let language = Self.currentAppLanguage()
            CancellationNotificationManager.shared.handleNewlyCanceled(
                newlyCanceled,
                seasonYear: decoded.seasonYear,
                language: language
            )
        }
        saveKnownCanceledScreeningIDs(canceledIDsNow)
    }
    #endif

    private func applyPublicConfigDocument(_ data: [String: Any]) {
        do {
            let payload = try JSONSerialization.data(withJSONObject: data)
            let doc = try JSONDecoder().decode(FestivalPublicConfigDocument.self, from: payload)
            publicConfig = try FestivalPublicConfig.decode(from: doc)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    // MARK: - Disk cache (offline)

    private var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("FestivalData", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cacheProgramDocument(_ data: [String: Any], year: Int) {
        guard JSONSerialization.isValidJSONObject(data),
              let encoded = try? JSONSerialization.data(withJSONObject: data, options: [.sortedKeys]) else { return }
        let url = cacheDirectory.appendingPathComponent("season-\(year).json")
        try? encoded.write(to: url, options: .atomic)
    }

    private func loadCachedSeasonIfAvailable(year: Int) {
        let url = cacheDirectory.appendingPathComponent("season-\(year).json")
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let legacy = cacheDirectory.appendingPathComponent("program.json")
            guard let legacyData = try? Data(contentsOf: legacy),
                  let legacyObject = try? JSONSerialization.jsonObject(with: legacyData) as? [String: Any] else { return }
            applyProgramDocument(legacyObject, source: .cache, expectedYear: year)
            return
        }
        applyProgramDocument(object, source: .cache, expectedYear: year)
    }
}

enum FirestorePaths {
    static let seasonsCollection = "seasons"
    static let publicConfig = "cinetransat/publicConfig"

    static func season(_ year: Int) -> String {
        "\(seasonsCollection)/\(year)"
    }
}

extension FestivalProgramStore {
    static let preview: FestivalProgramStore = {
        FestivalProgramStore(startListeners: false)
    }()

    private static func currentAppLanguage() -> AppLanguage {
        let raw = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.fr.rawValue
        return AppLanguage(rawValue: raw) ?? .fr
    }
}
