import Foundation
import GRDB

final class DatabaseManager {
    static let shared = DatabaseManager()

    let dbPool: DatabasePool

    private init() {
        let fileManager = FileManager.default
        var folderURL: URL
        do {
            folderURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("ClipFlow", isDirectory: true)

            if !fileManager.fileExists(atPath: folderURL.path) {
                try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            }
        } catch {
            print("[Database] Failed to create app support directory: \(error)")
            folderURL = fileManager.temporaryDirectory.appendingPathComponent("ClipFlow", isDirectory: true)
            try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }

        let dbURL = folderURL.appendingPathComponent("clipflow.sqlite")
        print("[Database] Database path: \(dbURL.path)")

        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "PRAGMA synchronous = NORMAL")
        }

        var pool: DatabasePool?
        do {
            pool = try DatabasePool(path: dbURL.path, configuration: config)
            try pool?.write { db in
                try DatabaseManager.createTables(db: db)
            }
            print("[Database] Database initialized successfully")
        } catch {
            print("[Database] Failed to create database: \(error)")
            // 尝试删除旧数据库重新开始
            print("[Database] Attempting to remove old database and retry...")
            try? fileManager.removeItem(at: dbURL)
            do {
                pool = try DatabasePool(path: dbURL.path, configuration: config)
                try pool?.write { db in
                    try DatabaseManager.createTables(db: db)
                }
                print("[Database] Database reinitialized successfully")
            } catch {
                fatalError("[Database] Critical: Cannot create database after retry: \(error)")
            }
        }
        self.dbPool = pool!
    }

    private static func createTables(db: Database) throws {
        try db.create(table: "clipboard_items", ifNotExists: true) { t in
            t.column("id", .text).primaryKey()
            t.column("content", .text).notNull()
            t.column("contentType", .text).notNull()
            t.column("imagePath", .text)
            t.column("thumbnailPath", .text)
            t.column("createdAt", .datetime).notNull()
            t.column("contentHash", .integer).notNull().defaults(to: 0)
        }

        try db.create(table: "tags", ifNotExists: true) { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull().unique()
            t.column("color", .text).notNull().defaults(to: "blue")
            t.column("createdAt", .datetime).notNull()
        }

        try db.create(table: "item_tags", ifNotExists: true) { t in
            t.column("item_id", .text).notNull().references("clipboard_items", onDelete: .cascade)
            t.column("tag_id", .text).notNull().references("tags", onDelete: .cascade)
            t.primaryKey(["item_id", "tag_id"])
        }

        // 使用 IF NOT EXISTS 防止索引已存在的错误
        _ = try? db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_items_created_at ON clipboard_items(createdAt)")
        _ = try? db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_items_content_hash ON clipboard_items(contentHash)")
        _ = try? db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_item_tags_item ON item_tags(item_id)")
        _ = try? db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_item_tags_tag ON item_tags(tag_id)")
    }

    func createClipboardItem(
        content: String,
        contentType: ClipboardItem.ContentType,
        imagePath: String? = nil,
        thumbnailPath: String? = nil,
        contentHash: Int = 0,
        tagNames: [String] = []
    ) throws -> ClipboardItem {
        let item = ClipboardItem(
            content: content,
            contentType: contentType,
            imagePath: imagePath,
            thumbnailPath: thumbnailPath,
            contentHash: contentHash
        )

        try dbPool.write { db in
            try item.insert(db)

            for tagName in tagNames {
                let tag = try self.getOrCreateTag(name: tagName, in: db)
                try db.execute(
                    sql: "INSERT OR IGNORE INTO item_tags (item_id, tag_id) VALUES (?, ?)",
                    arguments: [item.id.uuidString, tag.id.uuidString]
                )
            }
        }

        return item
    }

    func fetchClipboardItems(
        limit: Int = 100,
        offset: Int = 0,
        searchText: String? = nil,
        tagFilter: String? = nil
    ) throws -> [ClipboardItem] {
        try dbPool.read { db in
            var sql = "SELECT DISTINCT i.* FROM clipboard_items i"

            var conditions: [String] = []
            var arguments: [DatabaseValueConvertible] = []

            if tagFilter != nil {
                sql += " LEFT JOIN item_tags it ON i.id = it.item_id"
                sql += " LEFT JOIN tags t ON it.tag_id = t.id"
            }

            if let searchText = searchText, !searchText.isEmpty {
                conditions.append("i.content LIKE ?")
                arguments.append("%\(searchText)%")
            }

            if let tagFilter = tagFilter {
                conditions.append("t.name = ?")
                arguments.append(tagFilter)
            }

            if !conditions.isEmpty {
                sql += " WHERE " + conditions.joined(separator: " AND ")
            }

            sql += " ORDER BY i.createdAt DESC LIMIT ? OFFSET ?"
            arguments.append(limit)
            arguments.append(offset)

            var items = try ClipboardItem.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))

            for index in items.indices {
                items[index].tags = try self.fetchTagsForItem(id: items[index].id, in: db)
            }
            return items
        }
    }

    func fetchClipboardItem(by id: UUID) throws -> ClipboardItem? {
        try dbPool.read { db in
            guard var item = try ClipboardItem.fetchOne(db, key: ["id": id.uuidString]) else {
                return nil
            }
            item.tags = try fetchTagsForItem(id: id, in: db)
            return item
        }
    }

    func updateClipboardItem(
        id: UUID,
        content: String? = nil,
        imagePath: String? = nil,
        thumbnailPath: String? = nil
    ) throws {
        try dbPool.write { db in
            guard var item = try ClipboardItem.fetchOne(db, key: ["id": id.uuidString]) else { return }

            if let content = content {
                item.content = content
            }
            if let imagePath = imagePath {
                item.imagePath = imagePath
            }
            if let thumbnailPath = thumbnailPath {
                item.thumbnailPath = thumbnailPath
            }

            try item.update(db)
        }
    }

    func updateItemContent(id: UUID, content: String) throws {
        try dbPool.write { db in
            guard var item = try ClipboardItem.fetchOne(db, key: ["id": id.uuidString]) else { return }
            item.content = content
            try item.update(db)
        }
    }

    func deleteClipboardItem(id: UUID) throws {
        try dbPool.write { db in
            try db.execute(sql: "DELETE FROM item_tags WHERE item_id = ?", arguments: [id.uuidString])
            try ClipboardItem.deleteOne(db, key: ["id": id.uuidString])
        }
    }

    func deleteAllClipboardItems() throws {
        try dbPool.write { db in
            try db.execute(sql: "DELETE FROM item_tags")
            try db.execute(sql: "DELETE FROM clipboard_items")
        }
    }

    func cleanupExcessItems(keepCount: Int) throws {
        try dbPool.write { db in
            let idsToDelete = try String.fetchAll(db, sql: """
                SELECT id FROM clipboard_items
                ORDER BY createdAt DESC
                LIMIT -1 OFFSET ?
            """, arguments: [keepCount])

            guard !idsToDelete.isEmpty else { return }

            let placeholders = idsToDelete.map { _ in "?" }.joined(separator: ",")
            try db.execute(sql: """
                DELETE FROM item_tags WHERE item_id IN (\(placeholders))
            """, arguments: StatementArguments(idsToDelete))

            try db.execute(sql: """
                DELETE FROM clipboard_items WHERE id IN (\(placeholders))
            """, arguments: StatementArguments(idsToDelete))
        }
    }

    func existsItem(withHash hash: Int) throws -> Bool {
        try dbPool.read { db in
            let count = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM clipboard_items WHERE contentHash = ?
            """, arguments: [hash]) ?? 0
            return count > 0
        }
    }

    func createTag(name: String, color: String = "blue") throws -> Tag {
        let tag = Tag(name: name, color: color)
        try dbPool.write { db in
            try tag.insert(db)
        }
        return tag
    }

    func fetchAllTags() throws -> [Tag] {
        try dbPool.read { db in
            try Tag.fetchAll(db, sql: "SELECT * FROM tags ORDER BY name")
        }
    }

    func fetchTag(byName name: String) throws -> Tag? {
        try dbPool.read { db in
            try Tag.fetchOne(db, sql: "SELECT * FROM tags WHERE name = ?", arguments: [name])
        }
    }

    func fetchTag(byId id: UUID) throws -> Tag? {
        try dbPool.read { db in
            try Tag.fetchOne(db, key: ["id": id.uuidString])
        }
    }

    func deleteTag(id: UUID) throws {
        try dbPool.write { db in
            try Tag.deleteOne(db, key: ["id": id.uuidString])
        }
    }

    func updateTagColor(id: UUID, color: String) throws {
        try dbPool.write { db in
            guard var tag = try Tag.fetchOne(db, key: ["id": id.uuidString]) else { return }
            tag.color = color
            try tag.update(db)
        }
    }

    func updateTagName(id: UUID, name: String) throws {
        try dbPool.write { db in
            guard var tag = try Tag.fetchOne(db, key: ["id": id.uuidString]) else { return }
            tag.name = name
            try tag.update(db)
        }
    }

    func updateItemTags(itemId: UUID, tagIds: [UUID]) throws {
        _ = try dbPool.write { db in
            try db.execute(sql: "DELETE FROM item_tags WHERE item_id = ?", arguments: [itemId.uuidString])

            for tagId in tagIds {
                try db.execute(
                    sql: "INSERT INTO item_tags (item_id, tag_id) VALUES (?, ?)",
                    arguments: [itemId.uuidString, tagId.uuidString]
                )
            }
        }
    }
    
    func fetchTagsForItem(itemId: UUID) throws -> [Tag] {
        try dbPool.read { db in
            try fetchTagsForItem(id: itemId, in: db)
        }
    }

    private func getOrCreateTag(name: String, in db: Database) throws -> Tag {
        if let existing = try Tag.fetchOne(db, sql: "SELECT * FROM tags WHERE name = ?", arguments: [name]) {
            return existing
        }

        let tag = Tag(name: name, color: Tag.colorForName("blue"))
        try tag.insert(db)
        return tag
    }

    private func fetchTagsForItem(id: UUID, in db: Database) throws -> [Tag] {
        try Tag.fetchAll(db, sql: """
            SELECT t.* FROM tags t
            INNER JOIN item_tags it ON t.id = it.tag_id
            WHERE it.item_id = ?
            ORDER BY t.name
        """, arguments: [id.uuidString])
    }
}
