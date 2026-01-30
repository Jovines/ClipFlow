import Cocoa
import Combine
import Foundation
import GRDB

// MARK: - NSImage Extension

extension NSImage {
    func resized(to newSize: CGSize) -> NSImage {
        let image = NSImage(size: newSize)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(in: CGRect(origin: .zero, size: newSize), from: .zero, operation: .copy, fraction: 1.0)
        image.unlockFocus()
        return image
    }
}

// MARK: - Image Cache Manager

final class ImageCacheManager {
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

// MARK: - Image Optimizer

enum ImageOptimizer {
    static let thumbnailSize = CGSize(width: 120, height: 120)
    static let maxImageDimension: CGFloat = 2048
    static let thumbnailCompressionQuality: CGFloat = 0.7
    static let fullCompressionQuality: CGFloat = 0.85

    static func compressImage(_ nsImage: NSImage, quality: CGFloat = fullCompressionQuality) -> Data? {
        let resizedImage = resizeIfNeeded(nsImage)
        guard let resizedTiff = resizedImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: resizedTiff) else { return nil }
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }

    static func generateThumbnail(from nsImage: NSImage) -> Data? {
        let thumbnail = nsImage.resized(to: thumbnailSize)
        guard let tiff = thumbnail.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: thumbnailCompressionQuality])
    }

    private static func resizeIfNeeded(_ image: NSImage) -> NSImage {
        let size = image.size
        guard size.width > maxImageDimension || size.height > maxImageDimension else { return image }
        let scale = min(maxImageDimension / size.width, maxImageDimension / size.height)
        return image.resized(to: CGSize(width: size.width * scale, height: size.height * scale))
    }
}

// MARK: - Clipboard Content Detector

enum ClipboardContentDetector {
    static func hasReadableContent(from pasteboard: NSPasteboard) -> Bool {
        let types = pasteboard.types ?? []

        if types.contains(.tiff) || types.contains(.png) {
            return true
        }

        if types.contains(.string) {
            if let string = pasteboard.string(forType: .string), !string.isEmpty {
                return true
            }
        }

        return false
    }

    static func containsSensitiveData(_ content: String) -> Bool {
        let patterns = [
            "\\b(?:\\d{4}[-\\s]?){3}\\d{4}\\b",
            "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
            "(?i)(?:password|passwd|pwd|secret|token|key|api[_-]?key|auth)[\\s:]*\\S+",
            "(?:AKIA|ABIA|ACCA|ASIA)[A-Z0-9]{16}",
            "-----BEGIN\\s+(?:RSA\\s+)?PRIVATE KEY-----",
            "eyJ[A-Za-z0-9_-]*\\.eyJ[A-Za-z0-9_-]*\\.[A-Za-z0-9_-]*",
            "\\b\\d{3}[-\\s]?\\d{2}[-\\s]?\\d{4}\\b"
        ]

        for pattern in patterns {
            if content.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }

        return false
    }

    static func contentRiskLevel(_ content: String) -> RiskLevel {
        if containsSensitiveData(content) {
            return .high
        }
        return .low
    }

    enum RiskLevel {
        case low
        case medium
        case high
    }
}

// MARK: - Clipboard Monitor

final class ClipboardMonitor: ObservableObject {
    static let shared = ClipboardMonitor()

    @Published private(set) var capturedItems: [ClipboardItem] = []
    @Published private(set) var isMonitoring = false
    @Published private(set) var pasteboardAccessPermission: Bool = true

    private let pasteboard = NSPasteboard.general
    private var changeCount: Int = 0
    private let changeCountLock = NSLock()
    private var pasteboardObserver: NSObjectProtocol?
    private var timer: Timer?
    private let database = DatabaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var recentHashes: Set<Int> = []
    private let maxRecentHashes = 1000
    private var hashCacheLock = NSLock()
    private let monitorQueue = DispatchQueue(label: "com.clipflow.monitor", qos: .userInitiated)

    private init() {
        self.changeCount = pasteboard.changeCount
        setupBindings()
    }

    deinit {
        stop()
        if let observer = pasteboardObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func start() {
        guard !isMonitoring else {
            ClipFlowLogger.info("Clipboard monitoring already started, skipping")
            return
        }

        setupPasteboardObserver()
        setupTimerPolling()

        changeCountLock.lock()
        changeCount = pasteboard.changeCount
        changeCountLock.unlock()

        isMonitoring = true
        loadRecentItems()
        ClipFlowLogger.info("Clipboard monitoring started - changeCount: \(changeCount), pasteboard: \(pasteboard.name)")
    }

    func stop() {
        guard isMonitoring else { return }

        if let observer = pasteboardObserver {
            NotificationCenter.default.removeObserver(observer)
            pasteboardObserver = nil
        }

        timer?.invalidate()
        timer = nil

        isMonitoring = false
        ClipFlowLogger.info("Clipboard monitoring stopped")
    }

    func copyToClipboard(_ item: ClipboardItem) {
        monitorQueue.async { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.pasteboard.clearContents()
                switch item.contentType {
                case .text:
                    self.pasteboard.setString(item.content, forType: .string)
                case .image:
                    if let imagePath = item.imagePath,
                       let imageData = ImageCacheManager.shared.loadImage(forKey: imagePath),
                       let image = NSImage(data: imageData) {
                        self.pasteboard.writeObjects([image])
                    }
                }
            }
        }
    }

    func loadRecentItems(limit: Int = 50) {
        do {
            capturedItems = try database.fetchClipboardItems(limit: limit)
        } catch {
            ClipFlowLogger.error("Failed to load recent items: \(error)")
            capturedItems = []
        }
    }

    func refresh() {
        loadRecentItems()
    }

    func deleteItem(_ item: ClipboardItem) {
        if let index = capturedItems.firstIndex(where: { $0.id == item.id }) {
            if let imagePath = item.imagePath {
                ImageCacheManager.shared.deleteImage(forKey: imagePath)
            }
            if let thumbnailPath = item.thumbnailPath {
                ImageCacheManager.shared.deleteImage(forKey: thumbnailPath)
            }
            do {
                try database.deleteClipboardItem(id: item.id)
                capturedItems.remove(at: index)
            } catch {
                ClipFlowLogger.error("Failed to delete item: \(error)")
            }
        }
    }

    func updateItem(_ item: ClipboardItem) {
        if let index = capturedItems.firstIndex(where: { $0.id == item.id }) {
            do {
                try database.updateClipboardItem(
                    id: item.id,
                    content: item.content,
                    imagePath: item.imagePath,
                    thumbnailPath: item.thumbnailPath
                )
                capturedItems[index] = item
            } catch {
                ClipFlowLogger.error("Failed to update item: \(error)")
            }
        }
    }

    func updateItemContent(id: UUID, newContent: String) {
        if let index = capturedItems.firstIndex(where: { $0.id == id }) {
            do {
                try database.updateItemContent(id: id, content: newContent)
                capturedItems[index].content = newContent
            } catch {
                ClipFlowLogger.error("Failed to update item content: \(error)")
            }
        }
    }

    func moveItemToTop(id: UUID) {
        if let index = capturedItems.firstIndex(where: { $0.id == id }) {
            let item = capturedItems[index]
            var updatedItem = item
            updatedItem.createdAt = Date()
            capturedItems.remove(at: index)
            capturedItems.insert(updatedItem, at: 0)
            do {
                try database.updateClipboardItem(id: id, content: updatedItem.content)
            } catch {
                ClipFlowLogger.error("Failed to update item timestamp: \(error)")
            }
        }
    }

    func clearAllHistory() {
        ImageCacheManager.shared.clearCache()
        do {
            try database.deleteAllClipboardItems()
            recentHashes.removeAll()
            capturedItems.removeAll()
        } catch {
            ClipFlowLogger.error("Failed to clear history: \(error)")
        }
    }

    private func setupBindings() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .compactMap { $0.object as? UserDefaults }
            .sink { [weak self] defaults in
                if defaults.string(forKey: "maxHistoryItems") != nil {
                    self?.loadRecentItems()
                }
            }
            .store(in: &cancellables)
    }

    private func setupPasteboardObserver() {
        pasteboardObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSPasteboardDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handlePasteboardChange()
        }
    }

    private func setupTimerPolling() {
        let interval = UserDefaults.standard.double(forKey: "pollingInterval")
        let effectiveInterval = interval > 0 ? interval : 1.0

        timer = Timer.scheduledTimer(withTimeInterval: effectiveInterval, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    private func handlePasteboardChange() {
        monitorQueue.async { [weak self] in
            self?.checkClipboard()
        }
    }

    private func checkClipboard() {
        changeCountLock.lock()
        let currentChangeCount = pasteboard.changeCount
        let lastChangeCount = self.changeCount
        self.changeCount = currentChangeCount
        changeCountLock.unlock()

        guard currentChangeCount != lastChangeCount else { return }

        ClipFlowLogger.info("Clipboard changed detected - changeCount: \(currentChangeCount)")

        if !ClipboardContentDetector.hasReadableContent(from: pasteboard) {
            ClipFlowLogger.info("No readable content in pasteboard - types: \(pasteboard.types ?? [])")
            return
        }

        if let item = readFromPasteboard() {
            guard !isDuplicate(item) else {
                ClipFlowLogger.info("Duplicate item skipped")
                return
            }
            saveToDatabase(item)
            addToHashCache(item.contentHash)

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.capturedItems.insert(item, at: 0)
                self.enforceHistoryLimit()
                ClipFlowLogger.info("Captured new item - type: \(item.contentType), content: \(item.content.prefix(50))...")
            }
        } else {
            ClipFlowLogger.info("Failed to read from pasteboard")
        }
    }

    private func readFromPasteboard() -> ClipboardItem? {
        let shouldSaveImages = UserDefaults.standard.bool(forKey: "saveImages")

        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            guard shouldSaveImages else {
                ClipFlowLogger.debug("Image capture skipped - saveImages is disabled")
                return nil
            }

            guard let compressedData = ImageOptimizer.compressImage(image),
                  let thumbnailData = ImageOptimizer.generateThumbnail(from: image) else {
                return nil
            }

            let imageKey = UUID().uuidString
            _ = ImageCacheManager.shared.saveImage(compressedData, forKey: imageKey)
            _ = ImageCacheManager.shared.saveImage(thumbnailData, forKey: "\(imageKey)_thumb")

            return ClipboardItem(
                content: "Image",
                contentType: .image,
                imagePath: imageKey,
                thumbnailPath: "\(imageKey)_thumb",
                contentHash: compressedData.hashValue
            )
        }

        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            return ClipboardItem(
                content: string,
                contentType: .text,
                contentHash: string.hashValue
            )
        }

        return nil
    }

    private func saveToDatabase(_ item: ClipboardItem) {
        do {
            _ = try database.createClipboardItem(
                content: item.content,
                contentType: item.contentType,
                imagePath: item.imagePath,
                thumbnailPath: item.thumbnailPath,
                contentHash: item.contentHash,
                tagNames: item.tags.map { $0.name }
            )
        } catch {
            ClipFlowLogger.error("Failed to save to database: \(error)")
        }
    }

    private func isDuplicate(_ item: ClipboardItem) -> Bool {
        hashCacheLock.lock()
        let inMemoryCache = recentHashes.contains(item.contentHash)
        hashCacheLock.unlock()

        if inMemoryCache { return true }

        do {
            return try database.existsItem(withHash: item.contentHash)
        } catch {
            ClipFlowLogger.error("Failed to check duplicate: \(error)")
            return false
        }
    }

    private func addToHashCache(_ hash: Int) {
        hashCacheLock.lock()
        defer { hashCacheLock.unlock() }
        recentHashes.insert(hash)
        if recentHashes.count > maxRecentHashes {
            let toRemove = Array(recentHashes.prefix(recentHashes.count / 2))
            recentHashes.subtract(toRemove)
        }
    }

    private func enforceHistoryLimit() {
        let maxItems = UserDefaults.standard.integer(forKey: "maxHistoryItems")
        let effectiveMaxItems = maxItems > 0 ? maxItems : 100

        if capturedItems.count > effectiveMaxItems {
            let itemsToRemove = Array(capturedItems.suffix(from: effectiveMaxItems))

            for item in itemsToRemove where item.contentType == .image {
                if let imagePath = item.imagePath {
                    ImageCacheManager.shared.deleteImage(forKey: imagePath)
                }
                if let thumbnailPath = item.thumbnailPath {
                    ImageCacheManager.shared.deleteImage(forKey: thumbnailPath)
                }
            }

            capturedItems = Array(capturedItems.prefix(effectiveMaxItems))
            do {
                try database.cleanupExcessItems(keepCount: effectiveMaxItems)
            } catch {
                ClipFlowLogger.error("Failed to cleanup excess items: \(error)")
            }
        }
    }
}

// MARK: - ClipFlow Logger

enum ClipFlowLogger {
    private static var isDebugMode: Bool {
        #if DEBUG
        return true
        #else
        return UserDefaults.standard.bool(forKey: "debugMode")
        #endif
    }

    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard isDebugMode else { return }
        let fileName = (file as NSString).lastPathComponent
        print("[DEBUG] \(fileName):\(line) \(function) - \(message)")
    }

    static func info(_ message: String) {
        print("[INFO] \(message)")
    }

    static func warning(_ message: String) {
        print("[WARNING] \(message)")
    }

    static func error(_ message: String) {
        print("[ERROR] \(message)")
    }
}
