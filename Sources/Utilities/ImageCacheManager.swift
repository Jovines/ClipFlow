import Foundation
import AppKit

final class ImageCacheManager: @unchecked Sendable {
    static let shared = ImageCacheManager()

    private let cacheDirectory: URL
    private var maxCacheSize: Int
    private var maxItemCount: Int
    private let fileManager = FileManager.default

    private init() {
        let cachePath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cachePath.appendingPathComponent("com.clipflow.images", isDirectory: true)

        let configuredCacheSize = UserDefaults.standard.integer(forKey: "maxImageCacheSize")
        maxCacheSize = configuredCacheSize > 0 ? configuredCacheSize : 500 * 1024 * 1024

        let configuredItemCount = UserDefaults.standard.integer(forKey: "maxImageCacheCount")
        maxItemCount = configuredItemCount > 0 ? configuredItemCount : 500

        createCacheDirectoryIfNeeded()
    }

    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    func saveImage(_ data: Data, forKey key: String) -> URL? {
        createCacheDirectoryIfNeeded()
        let fileURL = cacheDirectory.appendingPathComponent(key)

        do {
            try data.write(to: fileURL)
            updateAccessTime(for: key)
            enforceCacheLimits()
            return fileURL
        } catch {
            ClipFlowLogger.error("Failed to save image to cache: \(error.localizedDescription)")
            return nil
        }
    }

    func loadImage(forKey key: String) -> Data? {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        updateAccessTime(for: key)
        return try? Data(contentsOf: fileURL)
    }

    func deleteImage(forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        try? fileManager.removeItem(at: fileURL)
    }

    func clearCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        createCacheDirectoryIfNeeded()
    }

    func cacheSize() -> Int64 {
        guard let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        return contents.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + Int64(size)
        }
    }

    func itemCount() -> Int {
        guard let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return 0
        }
        return contents.count
    }

    private func accessTimesFileURL() -> URL {
        cacheDirectory.appendingPathComponent("access_times.plist")
    }

    private func accessTimes() -> [String: Date] {
        guard let data = try? Data(contentsOf: accessTimesFileURL()),
              let times = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Date] else {
            return [:]
        }
        return times
    }

    private func saveAccessTimes(_ times: [String: Date]) {
        guard let data = try? PropertyListSerialization.data(fromPropertyList: times, format: .binary, options: 0) else { return }
        try? data.write(to: accessTimesFileURL())
    }

    private func updateAccessTime(for key: String) {
        var times = accessTimes()
        times[key] = Date()
        saveAccessTimes(times)
    }

    private func enforceCacheLimits() {
        var currentSize = cacheSize()
        guard currentSize > maxCacheSize || itemCount() > maxItemCount else { return }

        var accessTimes = accessTimes()
        let sortedKeys = accessTimes.sorted { $0.value < $1.value }.map { $0.key }

        for key in sortedKeys {
            deleteImage(forKey: key)
            accessTimes.removeValue(forKey: key)
            currentSize -= Int64((try? Data(contentsOf: cacheDirectory.appendingPathComponent(key)).count) ?? 0)
            if currentSize <= maxCacheSize && itemCount() <= maxItemCount { break }
        }
        saveAccessTimes(accessTimes)
    }
}
