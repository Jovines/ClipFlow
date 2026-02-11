import Foundation
import GRDB
import Combine

final class PromptTemplateService: ObservableObject, @unchecked Sendable {
    static let shared = PromptTemplateService()

    private init() {}

    func fetchAllTemplates() throws -> [PromptTemplate] {
        var templates = SystemPromptTemplates.all

        let customTemplates: [PromptTemplate] = try DatabaseManager.shared.dbPool.read { db in
            try PromptTemplateRecord.fetchAll(db, sql: """
                SELECT * FROM prompt_templates WHERE isSystem = 0 ORDER BY name ASC
                """).map { PromptTemplate(from: $0) }
        }

        templates.append(contentsOf: customTemplates)
        return templates
    }

    func fetchSystemTemplates() throws -> [PromptTemplate] {
        SystemPromptTemplates.all
    }

    func fetchCustomTemplates() throws -> [PromptTemplate] {
        try DatabaseManager.shared.dbPool.read { db in
            try PromptTemplateRecord.fetchAll(db, sql: """
                SELECT * FROM prompt_templates WHERE isSystem = 0 ORDER BY name ASC
                """).map { PromptTemplate(from: $0) }
        }
    }

    func fetchTemplate(by id: UUID) throws -> PromptTemplate? {
        if let systemTemplate = SystemPromptTemplates.template(for: id) {
            return systemTemplate
        }

        return try DatabaseManager.shared.dbPool.read { db in
            guard let record = try PromptTemplateRecord.fetchOne(db, sql: """
                SELECT * FROM prompt_templates WHERE id = ?
                """, arguments: [id]) else {
                return nil
            }
            return PromptTemplate(from: record)
        }
    }

    func createTemplate(
        name: String,
        description: String,
        initialPrompt: String,
        updatePrompt: String
    ) throws -> PromptTemplate {
        let template = PromptTemplate(
            name: name,
            description: description,
            initialPrompt: initialPrompt,
            updatePrompt: updatePrompt,
            isSystem: false
        )

        let record = PromptTemplateRecord(from: template)
        try DatabaseManager.shared.dbPool.write { db in
            try record.insert(db)
        }

        return template
    }

    func updateTemplate(_ template: PromptTemplate) throws {
        guard !template.isSystem else {
            throw PromptTemplateError.cannotModifySystemTemplate
        }

        var updatedTemplate = template
        updatedTemplate.updatedAt = Date()

        let record = PromptTemplateRecord(from: updatedTemplate)
        try DatabaseManager.shared.dbPool.write { db in
            try record.update(db)
        }
    }

    func deleteTemplate(id: UUID) throws {
        let isSystem = SystemPromptTemplates.all.contains { $0.id == id }
        guard !isSystem else {
            throw PromptTemplateError.cannotDeleteSystemTemplate
        }

        try DatabaseManager.shared.dbPool.write { db in
            try PromptTemplateRecord.deleteOne(db, key: ["id": id.uuidString])
        }

        try DatabaseManager.shared.dbPool.write { db in
            try db.execute(sql: """
                UPDATE projects SET selectedPromptTemplateId = NULL WHERE selectedPromptTemplateId = ?
                """, arguments: [id.uuidString])
        }
    }

    func duplicateTemplate(_ template: PromptTemplate) throws -> PromptTemplate {
        let newTemplate = PromptTemplate(
            name: String(format: "%1$@ Copy".localized(comment: "Duplicate template name"), template.name),
            description: template.description,
            initialPrompt: template.initialPrompt,
            updatePrompt: template.updatePrompt,
            isSystem: false
        )

        let record = PromptTemplateRecord(from: newTemplate)
        try DatabaseManager.shared.dbPool.write { db in
            try record.insert(db)
        }

        return newTemplate
    }
}

enum PromptTemplateError: LocalizedError {
    case cannotModifySystemTemplate
    case cannotDeleteSystemTemplate
    case templateNotFound

    var errorDescription: String? {
        switch self {
        case .cannotModifySystemTemplate:
            return "System Preset Template Cannot Be Modified".localized(comment: "Error message")
        case .cannotDeleteSystemTemplate:
            return "System Preset Template Cannot Be Deleted".localized(comment: "Error message")
        case .templateNotFound:
            return "Template Not Found".localized(comment: "Error message")
        }
    }
}
