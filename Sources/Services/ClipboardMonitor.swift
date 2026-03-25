// swiftlint:disable file_length
import Cocoa
import Combine
import Foundation
import GRDB
import OpenAI

final class ClipboardMonitor: ObservableObject, @unchecked Sendable {
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

            let wasMonitoring = self.isMonitoring
            if wasMonitoring {
                self.timer?.invalidate()
                self.timer = nil
            }

            DispatchQueue.main.async {
                self.pasteboard.clearContents()
                switch item.contentType {
                case .text:
                    self.writeTextItemToPasteboard(item)
                case .image:
                    if let imagePath = item.imagePath,
                       let imageData = ImageCacheManager.shared.loadImage(forKey: imagePath),
                       let image = NSImage(data: imageData) {
                        self.pasteboard.writeObjects([image])
                    }
                case .file:
                    let fileURLs = item.fileURLs.filter { FileManager.default.fileExists(atPath: $0.path) }
                    if !fileURLs.isEmpty {
                        let didWrite = self.pasteboard.writeObjects(fileURLs as [NSURL])
                        if !didWrite {
                            self.pasteboard.setString(item.content, forType: .string)
                        }
                    } else {
                        self.pasteboard.setString(item.content, forType: .string)
                    }
                }

                self.changeCountLock.lock()
                self.changeCount = self.pasteboard.changeCount
                self.changeCountLock.unlock()

                do {
                    try self.database.incrementUsageCount(for: item.id)

                    DispatchQueue.main.async {
                        if let index = self.capturedItems.firstIndex(where: { $0.id == item.id }) {
                            var updatedItem = self.capturedItems[index]
                            updatedItem.usageCount += 1
                            updatedItem.lastUsedAt = Date()
                            self.capturedItems.remove(at: index)
                            self.capturedItems.insert(updatedItem, at: 0)
                        }
                    }
                } catch {
                    ClipFlowLogger.error("Failed to update usage count: \(error)")
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self, wasMonitoring else { return }
                    self.setupTimerPolling()
                    self.changeCountLock.lock()
                    self.changeCount = self.pasteboard.changeCount
                    self.changeCountLock.unlock()
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
        ClipFlowLogger.info("[deleteItem] 开始删除 item: id=\(item.id.uuidString), content=\(item.content.prefix(50))")
        if let index = capturedItems.firstIndex(where: { $0.id == item.id }) {
            ClipFlowLogger.info("[deleteItem] 在 capturedItems 中找到 index=\(index)")
            cleanupCachedAssets(for: item)
            do {
                try database.deleteClipboardItem(id: item.id)
                capturedItems.remove(at: index)
                ClipFlowLogger.info("[deleteItem] 删除成功")
            } catch {
                ClipFlowLogger.error("Failed to delete item: \(error)")
            }
        } else {
            ClipFlowLogger.warning("[deleteItem] item 不在 capturedItems 中")
        }
    }

    func updateItem(_ item: ClipboardItem) {
        if let index = capturedItems.firstIndex(where: { $0.id == item.id }) {
            do {
                try database.updateClipboardItem(
                    id: item.id,
                    content: item.content,
                    imagePath: item.imagePath,
                    thumbnailPath: item.thumbnailPath,
                    richTextPath: item.richTextPath,
                    richTextType: item.richTextType
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
                if let richTextPath = capturedItems[index].richTextPath {
                    ImageCacheManager.shared.deleteData(forKey: richTextPath)
                }
                try database.updateItemContent(id: id, content: newContent)
                capturedItems[index].content = newContent
                capturedItems[index].richTextPath = nil
                capturedItems[index].richTextType = nil
            } catch {
                ClipFlowLogger.error("Failed to update item content: \(error)")
            }
        }
    }

    func updateItemNote(id: UUID, note: String?) {
        if let index = capturedItems.firstIndex(where: { $0.id == id }) {
            do {
                try database.updateItemNote(id: id, note: note)
                capturedItems[index].note = note
            } catch {
                ClipFlowLogger.error("Failed to update item note: \(error)")
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
}

extension ClipboardMonitor {

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
            if let existingItem = findExistingItem(item) {
                ClipFlowLogger.info("Duplicate item detected - updating timestamp and usage")
                let newCreatedAt = Date()
                do {
                    try database.updateItemTimestamp(for: existingItem.id, newCreatedAt: newCreatedAt)
                    try database.incrementUsageCount(for: existingItem.id)

                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        if let index = self.capturedItems.firstIndex(where: { $0.id == existingItem.id }) {
                            var updatedItem = self.capturedItems[index]
                            updatedItem.createdAt = newCreatedAt
                            updatedItem.usageCount += 1
                            updatedItem.lastUsedAt = Date()
                            self.capturedItems.remove(at: index)
                            self.capturedItems.insert(updatedItem, at: 0)
                        }
                        ClipFlowLogger.info("Updated existing item - id: \(existingItem.id)")
                    }
                } catch {
                    ClipFlowLogger.error("Failed to update existing item: \(error)")
                }
                return
            }

            let savedItem = saveToDatabase(item)
            addToHashCache(item.contentHash)

            // Check if in project mode and auto-add to project
            if let activeProjectId = ProjectService.shared.activeProjectId,
               let savedItem = savedItem {
                handleProjectMode(item: savedItem, projectId: activeProjectId)
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.capturedItems.insert(item, at: 0)
                self.enforceHistoryLimit()
                OnboardingState.setCapturedClipboardItem(true)
                ClipFlowLogger.info("Captured new item - type: \(item.contentType), content: \(item.content.prefix(50))...")
            }
        } else {
            ClipFlowLogger.info("Failed to read from pasteboard")
        }
    }
    
    private func handleProjectMode(item: ClipboardItem, projectId: UUID) {
        guard item.contentType == .text else {
            ClipFlowLogger.info("Skipping non-text item for project mode")
            return
        }
        
        // Add raw input to project
        let projectService = ProjectService.shared
        do {
            _ = try projectService.addRawInput(
                projectId: projectId,
                clipboardItemId: item.id
            )
            ClipFlowLogger.info("✅ Added item to project \(projectId): \(item.id)")
            
            // Note: AI analysis is now manually triggered by user
            ClipFlowLogger.info("📋 Item added. User can manually trigger AI analysis.")
        } catch {
            ClipFlowLogger.error("❌ Failed to add item to project: \(error)")
        }
    }
    
    private func analyzeProjectCognition(projectId: UUID, newInputId: UUID) async {
        ClipFlowLogger.info("🤖 Starting AI analysis for project \(projectId)")
        
        do {
            // Get project and current cognition
            let projectService = ProjectService.shared
            let cognitionService = ProjectCognitionService.shared
            
            guard let project = projectService.projects.first(where: { $0.id == projectId }) else {
                ClipFlowLogger.error("❌ Project not found: \(projectId)")
                return
            }
            ClipFlowLogger.info("📁 Found project: \(project.name)")
            
            let currentCognition = try? projectService.fetchCurrentCognition(for: projectId)
            ClipFlowLogger.info("📝 Current cognition: \(currentCognition != nil ? "exists" : "none")")
            
            // Get unanalyzed raw inputs
            let rawInputs = try projectService.fetchRawInputsWithItems(for: projectId)
            let unanalyzed = rawInputs.filter { !$0.input.isAnalyzed }
            
            ClipFlowLogger.info("📊 Total inputs: \(rawInputs.count), Unanalyzed: \(unanalyzed.count)")
            
            guard !unanalyzed.isEmpty else {
                ClipFlowLogger.info("⚠️ No unanalyzed inputs found")
                return
            }
            
            let newInputs: [(source: String?, content: String)] = unanalyzed.compactMap { tuple in
                guard tuple.item?.contentType == .text else { return nil }
                return (tuple.input.sourceContext, tuple.item?.content ?? "")
            }
            
            ClipFlowLogger.info("📝 Prepared \(newInputs.count) inputs for AI analysis")

            let content: String
            let changeDescription: String

            if let existingCognition = currentCognition {
                ClipFlowLogger.info("🔄 Updating existing cognition...")
                let (updatedContent, changeDesc) = try await cognitionService.updateCognition(
                    currentCognition: existingCognition.content,
                    projectName: project.name,
                    newInputs: newInputs
                )
                content = updatedContent
                changeDescription = changeDesc
            } else {
                ClipFlowLogger.info("🆕 Generating initial cognition...")
                content = try await cognitionService.generateInitialCognition(
                    projectName: project.name,
                    projectDescription: project.description,
                    initialInputs: newInputs
                )
                changeDescription = "初始认知文档生成"
            }

            ClipFlowLogger.info("💾 Saving cognition to database...")
            let addedInputIds = unanalyzed.map { $0.input.id }
            _ = try projectService.saveCognition(
                projectId: projectId,
                content: content,
                addedInputIds: addedInputIds,
                changeDescription: changeDescription
            )

            ClipFlowLogger.info("✅ Successfully updated cognition for project \(projectId)")

        } catch {
            ClipFlowLogger.error("❌ Failed to analyze project cognition: \(error)")
        }
    }
}

extension ClipboardMonitor {

    private struct RichTextPayload: Codable {
        let version: Int
        let richTextType: ClipboardItem.RichTextType
        let richData: Data
        let additionalData: [String: Data]
    }

    private func readFromPasteboard() -> ClipboardItem? {
        let shouldSaveImages = UserDefaults.standard.object(forKey: "saveImages") as? Bool ?? true

        if let fileItem = readFileItem() {
            return fileItem
        }

        if let textItem = readTextItem(shouldSaveImages: shouldSaveImages) {
            return textItem
        }

        if let imageItem = readImageItem(shouldSaveImages: shouldSaveImages) {
            return imageItem
        }

        return nil
    }

    private func readImageItem(shouldSaveImages: Bool) -> ClipboardItem? {
        guard let imagePayload = saveSupplementalImageFromPasteboard(shouldSaveImages: shouldSaveImages) else {
            return nil
        }

        return ClipboardItem(
            content: "Image".localized(),
            contentType: .image,
            imagePath: imagePayload.imagePath,
            thumbnailPath: imagePayload.thumbnailPath,
            contentHash: imagePayload.imageHash
        )
    }

    private func readFileItem() -> ClipboardItem? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]

        guard let rawURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] else {
            return nil
        }

        var seenPaths = Set<String>()
        var orderedPaths: [String] = []

        for url in rawURLs {
            let standardizedPath = url.standardizedFileURL.path
            guard !standardizedPath.isEmpty else { continue }

            if seenPaths.insert(standardizedPath).inserted {
                orderedPaths.append(standardizedPath)
            }
        }

        guard !orderedPaths.isEmpty else { return nil }

        let content = orderedPaths.joined(separator: "\n")
        return ClipboardItem(
            content: content,
            contentType: .file,
            contentHash: content.hashValue
        )
    }

    private func readTextItem(shouldSaveImages: Bool) -> ClipboardItem? {
        if let richTextItem = readRichTextItem(shouldSaveImages: shouldSaveImages) {
            return richTextItem
        }

        let imagePayload = saveSupplementalImageFromPasteboard(shouldSaveImages: shouldSaveImages)

        if let plainText = readPlainTextContent() {
            var contentHash = plainText.hashValue
            if let imageHash = imagePayload?.imageHash {
                var hasher = Hasher()
                hasher.combine(plainText)
                hasher.combine(imageHash)
                contentHash = hasher.finalize()
            }

            return ClipboardItem(
                content: plainText,
                contentType: .text,
                imagePath: imagePayload?.imagePath,
                thumbnailPath: imagePayload?.thumbnailPath,
                contentHash: contentHash
            )
        }

        return nil
    }

    private func readRichTextItem(shouldSaveImages: Bool) -> ClipboardItem? {
        let imagePayload = saveSupplementalImageFromPasteboard(shouldSaveImages: shouldSaveImages)
        let candidates: [(type: ClipboardItem.RichTextType, pasteboardType: NSPasteboard.PasteboardType)] = [
            (.rtfd, .rtfd),
            (.rtf, .rtf),
            (.html, .html)
        ]

        for candidate in candidates {
            guard let richData = pasteboard.data(forType: candidate.pasteboardType),
                  let plainText = attributedStringText(from: richData, type: documentType(for: candidate.type)) else {
                continue
            }

            let richTextKey = "rich_text_\(UUID().uuidString)"
            let supplementalData = supplementalPasteboardData(excluding: [candidate.pasteboardType, .string])
            let storedRichData = encodedRichTextPayload(
                richTextType: candidate.type,
                richData: richData,
                additionalData: supplementalData
            ) ?? richData

            guard ImageCacheManager.shared.saveData(storedRichData, forKey: richTextKey) != nil else {
                return ClipboardItem(
                    content: plainText,
                    contentType: .text,
                    contentHash: plainText.hashValue
                )
            }

            var hasher = Hasher()
            hasher.combine(plainText)
            hasher.combine(richData)
            hasher.combine(candidate.type.rawValue)
            hasher.combine(supplementalData.count)
            for key in supplementalData.keys.sorted() {
                hasher.combine(key)
                hasher.combine(supplementalData[key])
            }
            if let imageHash = imagePayload?.imageHash {
                hasher.combine(imageHash)
            }

            return ClipboardItem(
                content: plainText,
                contentType: .text,
                imagePath: imagePayload?.imagePath,
                thumbnailPath: imagePayload?.thumbnailPath,
                richTextPath: richTextKey,
                richTextType: candidate.type,
                contentHash: hasher.finalize()
            )
        }

        return nil
    }

    private func readPlainTextContent() -> String? {
        if let plainString = pasteboard.string(forType: .string),
           !plainString.isEmpty {
            return plainString
        }

        if let urlString = pasteboard.string(forType: .URL),
           !urlString.isEmpty {
            return urlString
        }

        if let htmlData = pasteboard.data(forType: .html),
           let htmlText = attributedStringText(from: htmlData, type: .html) {
            return htmlText
        }

        if let rtfData = pasteboard.data(forType: .rtf),
           let rtfText = attributedStringText(from: rtfData, type: .rtf) {
            return rtfText
        }

        if let rtfdData = pasteboard.data(forType: .rtfd),
           let rtfdText = attributedStringText(from: rtfdData, type: .rtfd) {
            return rtfdText
        }

        if let strings = pasteboard.readObjects(forClasses: [NSString.self], options: nil) as? [NSString],
           let first = strings.first {
            let fallback = first as String
            if !fallback.isEmpty {
                return fallback
            }
        }

        return nil
    }

    private func saveSupplementalImageFromPasteboard(shouldSaveImages: Bool) -> (imagePath: String, thumbnailPath: String, imageHash: Int)? {
        guard shouldSaveImages else { return nil }
        guard let image = NSImage(pasteboard: pasteboard),
              let compressedData = ImageOptimizer.compressImage(image),
              let thumbnailData = ImageOptimizer.generateThumbnail(from: image) else {
            return nil
        }

        let imageKey = UUID().uuidString
        _ = ImageCacheManager.shared.saveImage(compressedData, forKey: imageKey)
        let thumbnailKey = "\(imageKey)_thumb"
        _ = ImageCacheManager.shared.saveImage(thumbnailData, forKey: thumbnailKey)

        return (imageKey, thumbnailKey, compressedData.hashValue)
    }

    private func supplementalPasteboardData(excluding excludedTypes: Set<NSPasteboard.PasteboardType>) -> [String: Data] {
        let allowedPrefixes = ["org.chromium.", "com.google."]
        let types = pasteboard.types ?? []

        var payload: [String: Data] = [:]
        for type in types {
            guard !excludedTypes.contains(type) else { continue }
            let rawValue = type.rawValue
            let shouldKeep = allowedPrefixes.contains { rawValue.hasPrefix($0) }
            guard shouldKeep, let data = pasteboard.data(forType: type) else { continue }
            payload[rawValue] = data
        }

        return payload
    }

    private func encodedRichTextPayload(
        richTextType: ClipboardItem.RichTextType,
        richData: Data,
        additionalData: [String: Data]
    ) -> Data? {
        guard !additionalData.isEmpty else { return richData }
        let payload = RichTextPayload(
            version: 1,
            richTextType: richTextType,
            richData: richData,
            additionalData: additionalData
        )
        return try? JSONEncoder().encode(payload)
    }

    private func decodedRichTextPayload(from data: Data) -> RichTextPayload? {
        try? JSONDecoder().decode(RichTextPayload.self, from: data)
    }
}

extension ClipboardMonitor {

    private func writeTextItemToPasteboard(_ item: ClipboardItem) {
        var wroteRichText = false

        if let richTextPath = item.richTextPath,
           let richTextType = item.richTextType,
           let richData = ImageCacheManager.shared.loadData(forKey: richTextPath) {
            if let payload = decodedRichTextPayload(from: richData),
               payload.richTextType == richTextType {
                wroteRichText = pasteboard.setData(payload.richData, forType: richTextType.pasteboardType)
                if wroteRichText {
                    for key in payload.additionalData.keys.sorted() {
                        guard let data = payload.additionalData[key] else { continue }
                        pasteboard.setData(data, forType: NSPasteboard.PasteboardType(key))
                    }
                }
            } else {
                wroteRichText = pasteboard.setData(richData, forType: richTextType.pasteboardType)
            }
        }

        if !wroteRichText || !item.content.isEmpty {
            pasteboard.setString(item.content, forType: .string)
        }

        if let imagePath = item.imagePath,
           let imageData = ImageCacheManager.shared.loadImage(forKey: imagePath),
           let image = NSImage(data: imageData),
           let tiffData = image.tiffRepresentation {
            pasteboard.setData(tiffData, forType: .tiff)
        }
    }

    private func documentType(for richTextType: ClipboardItem.RichTextType) -> NSAttributedString.DocumentType {
        switch richTextType {
        case .rtf:
            return .rtf
        case .rtfd:
            return .rtfd
        case .html:
            return .html
        }
    }

    private func attributedStringText(from data: Data, type: NSAttributedString.DocumentType) -> String? {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: type
        ]

        guard let attributed = try? NSAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        ) else {
            return nil
        }

        let text = attributed.string
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return text
    }

    private func saveToDatabase(_ item: ClipboardItem) -> ClipboardItem? {
        do {
            let savedItem = try database.createClipboardItem(
                id: item.id,
                content: item.content,
                contentType: item.contentType,
                imagePath: item.imagePath,
                thumbnailPath: item.thumbnailPath,
                richTextPath: item.richTextPath,
                richTextType: item.richTextType,
                contentHash: item.contentHash
            )
            return savedItem
        } catch {
            ClipFlowLogger.error("Failed to save to database: \(error)")
            return nil
        }
    }

    private func findExistingItem(_ item: ClipboardItem) -> ClipboardItem? {
        hashCacheLock.lock()
        let inMemoryCache = recentHashes.contains(item.contentHash)
        hashCacheLock.unlock()

        if inMemoryCache {
            if let cached = capturedItems.first(where: { $0.contentHash == item.contentHash }) {
                return cached
            }
        }

        do {
            return try database.fetchItem(withHash: item.contentHash)
        } catch {
            ClipFlowLogger.error("Failed to find existing item: \(error)")
            return nil
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

        do {
            let taggedItemIds = try database.fetchAllTaggedItemIds()
            let untaggedItems = capturedItems.filter { !taggedItemIds.contains($0.id) }

            if untaggedItems.count > effectiveMaxItems {
                let itemsToRemove = Array(untaggedItems.suffix(from: effectiveMaxItems))

                for item in itemsToRemove {
                    cleanupCachedAssets(for: item)
                }

                let removedIds = Set(itemsToRemove.map { $0.id })
                capturedItems.removeAll { removedIds.contains($0.id) }
                try database.cleanupExcessItems(keepCount: effectiveMaxItems)
            }
        } catch {
            ClipFlowLogger.error("Failed to cleanup excess items: \(error)")
        }
    }

    private func cleanupCachedAssets(for item: ClipboardItem) {
        if let imagePath = item.imagePath {
            ImageCacheManager.shared.deleteImage(forKey: imagePath)
            ClipFlowLogger.info("[cleanupCachedAssets] 删除图片: \(imagePath)")
        }

        if let thumbnailPath = item.thumbnailPath {
            ImageCacheManager.shared.deleteImage(forKey: thumbnailPath)
            ClipFlowLogger.info("[cleanupCachedAssets] 删除缩略图: \(thumbnailPath)")
        }

        if let richTextPath = item.richTextPath {
            ImageCacheManager.shared.deleteData(forKey: richTextPath)
            ClipFlowLogger.info("[cleanupCachedAssets] 删除富文本缓存: \(richTextPath)")
        }
    }
}
