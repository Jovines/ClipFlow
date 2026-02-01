import Foundation
import GRDB

// MARK: - Project

struct Project: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var description: String?
    var isActive: Bool
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
    var currentCognitionId: UUID?
    var selectedPromptTemplateId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case isActive
        case isArchived
        case createdAt
        case updatedAt
        case currentCognitionId
        case selectedPromptTemplateId
    }

    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        isActive: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        currentCognitionId: UUID? = nil,
        selectedPromptTemplateId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.isActive = isActive
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.currentCognitionId = currentCognitionId
        self.selectedPromptTemplateId = selectedPromptTemplateId
    }
}

// MARK: - ProjectRawInput

struct ProjectRawInput: Identifiable, Hashable, Codable {
    let id: UUID
    let projectId: UUID
    let clipboardItemId: UUID
    var sourceContext: String? // 来源信息，如"张三"、"会议记录"等
    var isAnalyzed: Bool
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case projectId
        case clipboardItemId
        case sourceContext
        case isAnalyzed
        case createdAt
    }
    
    init(
        id: UUID = UUID(),
        projectId: UUID,
        clipboardItemId: UUID,
        sourceContext: String? = nil,
        isAnalyzed: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.projectId = projectId
        self.clipboardItemId = clipboardItemId
        self.sourceContext = sourceContext
        self.isAnalyzed = isAnalyzed
        self.createdAt = createdAt
    }
}

// MARK: - ProjectCognition

struct ProjectCognition: Identifiable, Hashable, Codable {
    let id: UUID
    let projectId: UUID
    var content: String
    var version: Int
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, projectId, content, version, createdAt
    }

    init(
        id: UUID = UUID(),
        projectId: UUID,
        content: String,
        version: Int = 1,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.projectId = projectId
        self.content = content
        self.version = version
        self.createdAt = createdAt
    }
}

// MARK: - ProjectCognitionChange

struct ProjectCognitionChange: Identifiable, Codable {
    let id: UUID
    let projectId: UUID
    let fromCognitionId: UUID
    let toCognitionId: UUID
    var changeDescription: String
    var addedInputsJSON: String // 新增的原始输入ID JSON字符串
    var createdAt: Date
    
    var addedInputs: [UUID] {
        guard let data = addedInputsJSON.data(using: .utf8),
              let strings = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return strings.compactMap { UUID(uuidString: $0) }
    }
    
    init(
        id: UUID = UUID(),
        projectId: UUID,
        fromCognitionId: UUID,
        toCognitionId: UUID,
        changeDescription: String,
        addedInputs: [UUID] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.projectId = projectId
        self.fromCognitionId = fromCognitionId
        self.toCognitionId = toCognitionId
        self.changeDescription = changeDescription
        let strings = addedInputs.map { $0.uuidString }
        self.addedInputsJSON = (try? JSONEncoder().encode(strings)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        self.createdAt = createdAt
    }
}

// MARK: - Project with related data

struct ProjectWithData: Identifiable {
    let project: Project
    let currentCognition: ProjectCognition?
    let rawInputCount: Int
    
    var id: UUID { project.id }
    
    var name: String { project.name }
    var lastUpdated: Date { project.updatedAt }
}

// MARK: - Database Extensions

extension Project: FetchableRecord, PersistableRecord {
    static let databaseTableName = "projects"
    
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let description = Column(CodingKeys.description)
        static let isActive = Column(CodingKeys.isActive)
        static let isArchived = Column(CodingKeys.isArchived)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
        static let currentCognitionId = Column(CodingKeys.currentCognitionId)
        static let selectedPromptTemplateId = Column(CodingKeys.selectedPromptTemplateId)
    }
    
    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.name] = name
        container[Columns.description] = description
        container[Columns.isActive] = isActive
        container[Columns.isArchived] = isArchived
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
        container[Columns.currentCognitionId] = currentCognitionId
        container[Columns.selectedPromptTemplateId] = selectedPromptTemplateId
    }
}

extension ProjectRawInput: FetchableRecord, PersistableRecord {
    static let databaseTableName = "project_raw_inputs"
    
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let projectId = Column(CodingKeys.projectId)
        static let clipboardItemId = Column(CodingKeys.clipboardItemId)
        static let sourceContext = Column(CodingKeys.sourceContext)
        static let isAnalyzed = Column(CodingKeys.isAnalyzed)
        static let createdAt = Column(CodingKeys.createdAt)
    }
    
    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.projectId] = projectId
        container[Columns.clipboardItemId] = clipboardItemId
        container[Columns.sourceContext] = sourceContext
        container[Columns.isAnalyzed] = isAnalyzed
        container[Columns.createdAt] = createdAt
    }
}

extension ProjectCognition: FetchableRecord, PersistableRecord {
    static let databaseTableName = "project_cognitions"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let projectId = Column(CodingKeys.projectId)
        static let content = Column(CodingKeys.content)
        static let version = Column(CodingKeys.version)
        static let createdAt = Column(CodingKeys.createdAt)
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.projectId] = projectId
        container[Columns.content] = content
        container[Columns.version] = version
        container[Columns.createdAt] = createdAt
    }
}

extension ProjectCognitionChange: FetchableRecord, PersistableRecord {
    static let databaseTableName = "project_cognition_changes"
    
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let projectId = Column(CodingKeys.projectId)
        static let fromCognitionId = Column(CodingKeys.fromCognitionId)
        static let toCognitionId = Column(CodingKeys.toCognitionId)
        static let changeDescription = Column(CodingKeys.changeDescription)
        static let addedInputsJSON = Column(CodingKeys.addedInputsJSON)
        static let createdAt = Column(CodingKeys.createdAt)
    }
    
    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.projectId] = projectId
        container[Columns.fromCognitionId] = fromCognitionId
        container[Columns.toCognitionId] = toCognitionId
        container[Columns.changeDescription] = changeDescription
        container[Columns.addedInputsJSON] = addedInputsJSON
        container[Columns.createdAt] = createdAt
    }
}
