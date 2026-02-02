import Foundation
import GRDB

final class DatabaseManager: @unchecked Sendable {
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
            try db.execute(sql: "PRAGMA foreign_keys = ON")
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

        try db.create(table: "projects", ifNotExists: true) { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull()
            t.column("description", .text)
            t.column("isActive", .boolean).notNull().defaults(to: false)
            t.column("isArchived", .boolean).notNull().defaults(to: false)
            t.column("createdAt", .datetime).notNull()
            t.column("updatedAt", .datetime).notNull()
            t.column("currentCognitionId", .text)
        }

        try db.create(table: "project_raw_inputs", ifNotExists: true) { t in
            t.column("id", .text).primaryKey()
            t.column("projectId", .text).notNull().references("projects", onDelete: .cascade)
            t.column("clipboardItemId", .text).notNull().references("clipboard_items", onDelete: .cascade)
            t.column("sourceContext", .text)
            t.column("isAnalyzed", .boolean).notNull().defaults(to: false)
            t.column("createdAt", .datetime).notNull()
        }

        try db.create(table: "project_cognitions", ifNotExists: true) { t in
            t.column("id", .text).primaryKey()
            t.column("projectId", .text).notNull().references("projects", onDelete: .cascade)
            t.column("content", .text).notNull()
            t.column("version", .integer).notNull().defaults(to: 1)
            t.column("createdAt", .datetime).notNull()
        }

        try db.create(table: "project_cognition_changes", ifNotExists: true) { t in
            t.column("id", .text).primaryKey()
            t.column("projectId", .text).notNull().references("projects", onDelete: .cascade)
            t.column("fromCognitionId", .text).notNull().references("project_cognitions")
            t.column("toCognitionId", .text).notNull().references("project_cognitions")
            t.column("changeDescription", .text).notNull()
            t.column("addedInputsJSON", .text).notNull().defaults(to: "[]")
            t.column("createdAt", .datetime).notNull()
        }

        _ = try? db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_items_created_at ON clipboard_items(createdAt)")
        _ = try? db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_items_content_hash ON clipboard_items(contentHash)")
        _ = try? db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_projects_active ON projects(isActive)")
        _ = try? db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_projects_archived ON projects(isArchived)")
        _ = try? db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_raw_inputs_project ON project_raw_inputs(projectId)")
        _ = try? db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_cognitions_project ON project_cognitions(projectId)")

        try migratePromptTemplates(db: db)
    }

    private static func migratePromptTemplates(db: Database) throws {
        let templateTableExists = try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='prompt_templates'
            """) ?? 0

        if templateTableExists == 0 {
            try db.create(table: "prompt_templates", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("description", .text)
                t.column("initialPrompt", .text).notNull()
                t.column("updatePrompt", .text).notNull()
                t.column("isSystem", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_templates_system ON prompt_templates(isSystem)")

            try SystemPromptTemplates.all.forEach { template in
                try db.execute(sql: """
                    INSERT OR IGNORE INTO prompt_templates (id, name, description, initialPrompt, updatePrompt, isSystem, createdAt, updatedAt)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """, arguments: [
                        template.id.uuidString,
                        template.name,
                        template.description,
                        template.initialPrompt,
                        template.updatePrompt,
                        template.isSystem ? 1 : 0,
                        template.createdAt,
                        template.updatedAt
                    ])
            }

            print("[Database] Migration: Created prompt_templates table with system templates")
        }

        let projectColumnExists = try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM pragma_table_info('projects') WHERE name = 'selectedPromptTemplateId'
            """) ?? 0

        if projectColumnExists == 0 {
            try db.execute(sql: "ALTER TABLE projects ADD COLUMN selectedPromptTemplateId TEXT")
            print("[Database] Migration: Added selectedPromptTemplateId column to projects table")
        }

        let customPromptColumnExists = try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM pragma_table_info('projects') WHERE name = 'customPrompt'
            """) ?? 0

        if customPromptColumnExists > 0 {
            try db.execute(sql: "ALTER TABLE projects DROP COLUMN customPrompt")
            print("[Database] Migration: Removed deprecated customPrompt column from projects table")
        }
    }

    func createClipboardItem(
        id: UUID? = nil,
        content: String,
        contentType: ClipboardItem.ContentType,
        imagePath: String? = nil,
        thumbnailPath: String? = nil,
        contentHash: Int = 0
    ) throws -> ClipboardItem {
        let itemId = id ?? UUID()
        let item = ClipboardItem(
            id: itemId,
            content: content,
            contentType: contentType,
            imagePath: imagePath,
            thumbnailPath: thumbnailPath,
            contentHash: contentHash
        )

        try dbPool.write { db in
            try item.insert(db)
        }

        return item
    }

    func fetchClipboardItems(
        limit: Int = 100,
        offset: Int = 0,
        searchText: String? = nil
    ) throws -> [ClipboardItem] {
        try dbPool.read { db in
            var sql = "SELECT * FROM clipboard_items i"

            var conditions: [String] = []
            var arguments: [DatabaseValueConvertible] = []

            if let searchText = searchText, !searchText.isEmpty {
                conditions.append("i.content LIKE ?")
                arguments.append("%\(searchText)%")
            }

            if !conditions.isEmpty {
                sql += " WHERE " + conditions.joined(separator: " AND ")
            }

            sql += " ORDER BY i.createdAt DESC LIMIT ? OFFSET ?"
            arguments.append(limit)
            arguments.append(offset)

            return try ClipboardItem.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
        }
    }

    func fetchClipboardItem(by id: UUID) throws -> ClipboardItem? {
        try dbPool.read { db in
            try ClipboardItem.fetchOne(db, key: ["id": id.uuidString])
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
            try ClipboardItem.deleteOne(db, key: ["id": id.uuidString])
        }
    }

    func deleteAllClipboardItems() throws {
        try dbPool.write { db in
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

    struct DatabaseError: Error {
        let message: String
    }
}
