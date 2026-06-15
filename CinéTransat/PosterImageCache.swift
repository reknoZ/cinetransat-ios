//
//  PosterImageCache.swift
//  CinéTransat
//

import UIKit

/// Disk + HTTP cache for remote posters (survives app restarts; avoids re-downloading every launch).
final class PosterImageCache {
    static let shared = PosterImageCache()

    private let session: URLSession
    private let directory: URL
    private let ioQueue = DispatchQueue(label: "PosterImageCache.io", qos: .utility)

    private init() {
        let cache = URLCache(
            memoryCapacity: 40 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024
        )
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 25
        session = URLSession(configuration: config)

        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        directory = base.appendingPathComponent("PosterImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Instant hit when this poster was loaded in a previous session.
    func cachedImageIfPresent(posterKey: String) -> UIImage? {
        let url = fileURL(for: posterKey)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Loads from disk first, then remote URLs (first success wins). Writes to disk for next launch.
    func image(posterKey: String, remoteURLs: [URL], forceNetwork: Bool = false) async -> UIImage? {
        let fileURL = fileURL(for: posterKey)
        if !forceNetwork, let disk = await loadDisk(fileURL) {
            return disk
        }
        for url in remoteURLs {
            if let image = await download(url: url, forceNetwork: forceNetwork) {
                await saveDisk(image, to: fileURL)
                return image
            }
        }
        return nil
    }

    /// Drops cached HTTP responses for these URLs (e.g. after a failed 404 before the file existed on Hosting).
    func clearURLCache(for urls: [URL]) {
        for url in urls {
            session.configuration.urlCache?.removeCachedResponse(for: URLRequest(url: url))
            session.configuration.urlCache?.removeCachedResponse(for: URLRequest(url: cacheBustedURL(url)))
        }
    }

    /// Hosting sets `max-age=3600`; a new deploy can still look stale without a cache buster.
    private func cacheBustedURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        var items = components.queryItems ?? []
        items.removeAll { $0.name == "cb" }
        items.append(URLQueryItem(name: "cb", value: String(Int(Date().timeIntervalSince1970))))
        components.queryItems = items
        return components.url ?? url
    }

    private func fileURL(for posterKey: String) -> URL {
        let safe = posterKey
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return directory.appendingPathComponent("\(safe).img")
    }

    private func loadDisk(_ url: URL) async -> UIImage? {
        await withCheckedContinuation { continuation in
            ioQueue.async {
                guard let data = try? Data(contentsOf: url),
                      let image = UIImage(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }

    private func saveDisk(_ image: UIImage, to url: URL) async {
        guard let data = image.jpegData(compressionQuality: 0.88) else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ioQueue.async {
                try? data.write(to: url, options: .atomic)
                continuation.resume()
            }
        }
    }

    private func download(url: URL, forceNetwork: Bool) async -> UIImage? {
        let fetchURL = forceNetwork ? cacheBustedURL(url) : url
        var request = URLRequest(url: fetchURL)
        request.cachePolicy = forceNetwork ? .reloadIgnoringLocalCacheData : .returnCacheDataElseLoad
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                return nil
            }
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}
