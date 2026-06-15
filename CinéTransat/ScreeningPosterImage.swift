//
//  ScreeningPosterImage.swift
//  CinéTransat
//

import SwiftUI
import UIKit

private struct PosterDownloadsPausedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var posterDownloadsPaused: Bool {
        get { self[PosterDownloadsPausedKey.self] }
        set { self[PosterDownloadsPausedKey.self] = newValue }
    }
}

/// Loads a screening poster (disk cache → network → bundled asset → placeholder).
struct ScreeningPosterImage: View {
    @EnvironmentObject private var program: FestivalProgramStore
    @Environment(\.posterDownloadsPaused) private var posterDownloadsPaused

    let screening: Screening
    var posterBaseURLTemplate: String?

    @State private var loadedImage: UIImage?
    @State private var loadFailed = false

    init(screening: Screening, posterBaseURLTemplate: String? = nil) {
        self.screening = screening
        self.posterBaseURLTemplate = posterBaseURLTemplate
        _loadedImage = State(
            initialValue: PosterImageCache.shared.cachedImageIfPresent(posterKey: screening.posterKey)
        )
    }

    private var remoteCandidates: [URL] {
        screening.remotePosterURLs(posterBaseURLTemplate: posterBaseURLTemplate)
    }

    private var bundledAssetName: String? {
        screening.bundledPosterAssetName
    }

    var body: some View {
        Group {
            if screening.usesTBDPlaceholderPoster {
                TBDPosterPlaceholder()
            } else if let loadedImage {
                posterImage(Image(uiImage: loadedImage))
            } else if !loadFailed, !remoteCandidates.isEmpty {
                placeholderLayer
                    .overlay {
                        if loadedImage == nil, !posterDownloadsPaused {
                            ProgressView().tint(.white.opacity(0.7))
                        }
                    }
                    .task(id: "\(taskID)|paused:\(posterDownloadsPaused)") {
                        guard !posterDownloadsPaused else { return }
                        await loadRemote()
                    }
            } else if let name = bundledAssetName {
                posterImage(Image(name))
            } else {
                placeholderLayer
            }
        }
        .onChange(of: screening.id) { _, _ in
            syncLoadedImageFromCache()
        }
        .onChange(of: program.posterRefreshGeneration) { _, _ in
            loadFailed = false
            syncLoadedImageFromCache()
        }
    }

    private func syncLoadedImageFromCache() {
        loadedImage = PosterImageCache.shared.cachedImageIfPresent(posterKey: screening.posterKey)
        loadFailed = false
    }

    private var taskID: String {
        "\(screening.posterKey)|\(posterBaseURLTemplate ?? "")|\(program.posterRefreshGeneration)"
    }

    private func loadRemote(forceNetwork: Bool = false) async {
        if loadedImage != nil, !forceNetwork { return }
        guard !remoteCandidates.isEmpty else { return }
        if forceNetwork {
            PosterImageCache.shared.clearURLCache(for: remoteCandidates)
        }
        let image = await PosterImageCache.shared.image(
            posterKey: screening.posterKey,
            remoteURLs: remoteCandidates,
            forceNetwork: forceNetwork
        )
        guard !Task.isCancelled else { return }
        if let image {
            loadedImage = image
        } else {
            loadFailed = true
        }
    }

    private func posterImage(_ image: Image) -> some View {
        GeometryReader { geo in
            image
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(1.04)
                .clipped()
        }
    }

    private var placeholderLayer: some View {
        Color.clear
    }
}

/// Grey poster tile with a clapperboard icon for unannounced screenings.
struct TBDPosterPlaceholder: View {
    var body: some View {
        GeometryReader { geo in
            let iconSize = min(geo.size.width, geo.size.height) * 0.28
            ZStack {
                Color(red: 0.55, green: 0.57, blue: 0.60)
                Image(systemName: "movieclapper")
                    .font(.system(size: iconSize, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
        }
    }
}

extension Screening {
    func remotePosterURLs(posterBaseURLTemplate: String?) -> [URL] {
        if usesTBDPlaceholderPoster { return [] }
        if let posterURL, let url = URL(string: posterURL), url.scheme?.hasPrefix("http") == true {
            return [url]
        }
        guard let template = posterBaseURLTemplate?.trimmingCharacters(in: .whitespacesAndNewlines),
              !template.isEmpty else {
            return []
        }

        let stems = [posterKey] + PosterCatalog.alternateStems(for: posterKey)
        var urls: [URL] = []
        var seen = Set<String>()
        for stem in stems {
            for url in Self.remoteURLs(posterStem: stem, screeningID: id, template: template) {
                if seen.insert(url.absoluteString).inserted {
                    urls.append(url)
                }
            }
        }
        return urls
    }

    private static func remoteURLs(posterStem: String, screeningID: String, template: String) -> [URL] {
        let encoded = PosterURLEncoding.pathComponent(posterStem)
        let expanded = template
            .replacingOccurrences(of: "{posterKey}", with: encoded)
            .replacingOccurrences(of: "{id}", with: encoded)
            .replacingOccurrences(of: "{year}", with: String(screeningID.prefix(4)))

        if expanded.contains(".jpg") {
            let png = expanded.replacingOccurrences(of: ".jpg", with: ".png")
            return [expanded, png].compactMap(URL.init(string:))
        }
        if expanded.contains(".png") {
            let jpg = expanded.replacingOccurrences(of: ".png", with: ".jpg")
            return [expanded, jpg].compactMap(URL.init(string:))
        }
        return ["jpg", "png"].compactMap { ext in
            URL(string: "\(expanded).\(ext)")
        }
    }

    var bundledPosterAssetName: String? {
        if UIImage(named: posterKey, in: .main, compatibleWith: nil) != nil {
            return posterKey
        }
        if UIImage(named: id, in: .main, compatibleWith: nil) != nil {
            return id
        }
        return nil
    }
}
