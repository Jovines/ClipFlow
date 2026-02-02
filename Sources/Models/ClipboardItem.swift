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

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case contentType
        case imagePath
        case thumbnailPath
        case createdAt
        case contentHash
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
        contentHash: Int = 0
    ) {
        self.id = id
        self.content = content
        self.contentType = contentType
        self.imagePath = imagePath
        self.thumbnailPath = thumbnailPath
        self.createdAt = createdAt
        self.contentHash = contentHash
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
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.content] = content
        container[Columns.contentType] = contentType
        container[Columns.imagePath] = imagePath
        container[Columns.thumbnailPath] = thumbnailPath
        container[Columns.createdAt] = createdAt
        container[Columns.contentHash] = contentHash
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
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let color = Column(CodingKeys.color)
        static let createdAt = Column(CodingKeys.createdAt)
    }
    
    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
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
