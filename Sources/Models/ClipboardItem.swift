import Foundation
import GRDB

struct ClipboardItem: Identifiable, Hashable, Codable {
    let id: UUID
    var content: String
    var contentType: ContentType
    var imagePath: String?
    var thumbnailPath: String?
    var createdAt: Date
    var contentHash: Int
    var usageCount: Int
    var lastUsedAt: Date?
    var recommendationScore: Double
    var recommendedAt: Date?
    var evictedAt: Date?
    var note: String?

    enum CodingKeys: String, CodingKey {
        case id, content, contentType, imagePath, thumbnailPath
        case createdAt, contentHash, usageCount, lastUsedAt
        case recommendationScore, recommendedAt, evictedAt, note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        contentType = try container.decode(ContentType.self, forKey: .contentType)
        imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
        thumbnailPath = try container.decodeIfPresent(String.self, forKey: .thumbnailPath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        contentHash = try container.decode(Int.self, forKey: .contentHash)
        usageCount = try container.decodeIfPresent(Int.self, forKey: .usageCount) ?? 0
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        recommendationScore = try container.decodeIfPresent(Double.self, forKey: .recommendationScore) ?? 0
        recommendedAt = try container.decodeIfPresent(Date.self, forKey: .recommendedAt)
        evictedAt = try container.decodeIfPresent(Date.self, forKey: .evictedAt)
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }

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
        createdAt: Date = Date(),
        contentHash: Int = 0,
        usageCount: Int = 0,
        lastUsedAt: Date? = nil,
        recommendationScore: Double = 0,
        recommendedAt: Date? = nil,
        evictedAt: Date? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.content = content
        self.contentType = contentType
        self.imagePath = imagePath
        self.thumbnailPath = thumbnailPath
        self.createdAt = createdAt
        self.contentHash = contentHash
        self.usageCount = usageCount
        self.lastUsedAt = lastUsedAt
        self.recommendationScore = recommendationScore
        self.recommendedAt = recommendedAt
        self.evictedAt = evictedAt
        self.note = note
    }

    var hasImage: Bool {
        imagePath != nil
    }

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension ClipboardItem {
    static let minRecommendationScore: Double = 1.0

    static var recommendationDecayConstant: Double {
        let hours = UserDefaults.standard.double(forKey: "recommendationDecayHours")
        let halfLifeInDays = max(0.041, hours) / 24.0
        return log(2) / halfLifeInDays
    }

    static func calculateScore(usageCount: Int, daysSinceLastUse: Double) -> Double {
        Double(usageCount) * exp(-recommendationDecayConstant * daysSinceLastUse)
    }

    var daysSinceLastUse: Double {
        guard let lastUsed = lastUsedAt else { return .infinity }
        return Date().timeIntervalSince(lastUsed) / 86400
    }

    var currentScore: Double {
        guard usageCount > 0 else { return 0 }
        return Self.calculateScore(usageCount: usageCount, daysSinceLastUse: daysSinceLastUse)
    }

    var shouldBeRecommended: Bool {
        let minUsage = UserDefaults.standard.integer(forKey: "minUsageCountForRecommendation")
        return usageCount >= max(1, minUsage) && currentScore >= Self.minRecommendationScore
    }

    var recommendationPriority: Double {
        currentScore
    }

    var isCurrentlyRecommended: Bool {
        recommendedAt != nil && evictedAt == nil
    }

    var daysSinceEvicted: Double? {
        guard let evicted = evictedAt else { return nil }
        return Date().timeIntervalSince(evicted) / 86400
    }
}

extension ClipboardItem.ContentType: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        rawValue.databaseValue
    }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> ClipboardItem.ContentType? {
        guard let string = String.fromDatabaseValue(dbValue) else { return nil }
        return ClipboardItem.ContentType(rawValue: string)
    }
}

extension ClipboardItem: FetchableRecord, PersistableRecord {
    static let databaseTableName = "clipboard_items"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let content = Column(CodingKeys.content)
        static let contentType = Column(CodingKeys.contentType)
        static let imagePath = Column(CodingKeys.imagePath)
        static let thumbnailPath = Column(CodingKeys.thumbnailPath)
        static let createdAt = Column(CodingKeys.createdAt)
        static let contentHash = Column(CodingKeys.contentHash)
        static let usageCount = Column(CodingKeys.usageCount)
        static let lastUsedAt = Column(CodingKeys.lastUsedAt)
        static let recommendationScore = Column(CodingKeys.recommendationScore)
        static let recommendedAt = Column(CodingKeys.recommendedAt)
        static let evictedAt = Column(CodingKeys.evictedAt)
        static let note = Column(CodingKeys.note)
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id.uuidString
        container[Columns.content] = content
        container[Columns.contentType] = contentType
        container[Columns.imagePath] = imagePath
        container[Columns.thumbnailPath] = thumbnailPath
        container[Columns.createdAt] = createdAt
        container[Columns.contentHash] = contentHash
        container[Columns.usageCount] = usageCount
        container[Columns.lastUsedAt] = lastUsedAt
        container[Columns.recommendationScore] = recommendationScore
        container[Columns.recommendedAt] = recommendedAt
        container[Columns.evictedAt] = evictedAt
        container[Columns.note] = note
    }
}

struct Tag: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var color: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        color: String = "blue",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
    }
}

extension Tag: FetchableRecord, PersistableRecord {
    static let databaseTableName = "tags"

    enum Columns {
        static let id = Column("id")
        static let name = Column(CodingKeys.name)
        static let color = Column(CodingKeys.color)
        static let createdAt = Column(CodingKeys.createdAt)
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id.uuidString
        container[Columns.name] = name
        container[Columns.color] = color
        container[Columns.createdAt] = createdAt
    }

    static let availableColors: [(name: String, hex: String)] = [
        ("blue", "#205EA6"),
        ("green", "#66800B"),
        ("red", "#AF3029"),
        ("orange", "#BC5215"),
        ("purple", "#5E409D"),
        ("magenta", "#A02F6F"),
        ("yellow", "#AD8301"),
        ("cyan", "#24837B")
    ]

    static func colorForName(_ name: String) -> String {
        availableColors.first { $0.name == name }?.hex ?? "#007AFF"
    }

    static func nameForColor(_ hex: String) -> String {
        availableColors.first { $0.hex == hex }?.name ?? "blue"
    }
}
