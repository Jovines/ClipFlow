import Foundation

struct ClipboardItem: Identifiable, Hashable {
    let id: UUID
    var content: String
    var contentType: ContentType
    var imagePath: String?
    var thumbnailPath: String?
    var imageData: Data?
    var thumbnailData: Data?
    var createdAt: Date
    var tags: [Tag]
    var contentHash: Int

    enum ContentType: String, Codable {
        case text
        case image
    }

    init(
        id: UUID = UUID(),
        content: String,
        contentType: ContentType,
        imagePath: String? = nil,
        thumbnailPath: String? = nil,
        imageData: Data? = nil,
        thumbnailData: Data? = nil,
        createdAt: Date = Date(),
        tags: [Tag] = [],
        contentHash: Int = 0
    ) {
        self.id = id
        self.content = content
        self.contentType = contentType
        self.imagePath = imagePath
        self.thumbnailPath = thumbnailPath
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.createdAt = createdAt
        self.tags = tags
        self.contentHash = contentHash
    }

    var hasImage: Bool {
        imagePath != nil || imageData != nil
    }
    
    var contentHashValue: Int {
        switch contentType {
        case .text:
            return content.hashValue
        case .image:
            return imageData?.hashValue ?? 0
        }
    }
    
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Tag: Identifiable, Hashable {
    let id: UUID
    var name: String
    var color: String
    
    init(id: UUID = UUID(), name: String, color: String = "blue") {
        self.id = id
        self.name = name
        self.color = color
    }
}

extension Tag {
    static let availableColors: [(name: String, hex: String)] = [
        ("blue", "#007AFF"),
        ("green", "#34C759"),
        ("red", "#FF3B30"),
        ("orange", "#FF9500"),
        ("purple", "#AF52DE"),
        ("pink", "#FF2D55"),
        ("yellow", "#FFCC00"),
        ("gray", "#8E8E93")
    ]
    
    static func colorForName(_ name: String) -> String {
        availableColors.first { $0.name == name }?.hex ?? "#007AFF"
    }
    
    static func nameForColor(_ hex: String) -> String {
        availableColors.first { $0.hex == hex }?.name ?? "blue"
    }
}
