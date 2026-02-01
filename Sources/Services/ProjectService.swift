import Foundation
import GRDB
import Combine

final class ProjectService: ObservableObject {
    static let shared = ProjectService()
    
    @Published private var _activeProjectId: UUID?
    @Published private var _projects: [Project] = []
    
    var activeProject: Project? {
        guard let id = _activeProjectId else { return nil }
        return _projects.first { $0.id == id }
    }
    
    var activeProjectId: UUID? {
        get { _activeProjectId }
        set { 
            _activeProjectId = newValue
            if let id = newValue {
                try? activateProject(id: id)
            } else {
                try? deactivateAllProjects()
            }
        }
    }
    
    var projects: [Project] {
        _projects
    }
    
    var activeProjects: [Project] {
        _projects.filter { !$0.isArchived }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadProjects()
    }
    
    // MARK: - Project Management
    
    func createProject(name: String, description: String? = nil) throws -> Project {
        let project = Project(name: name, description: description)
        
        try DatabaseManager.shared.dbPool.write { db in
            try project.insert(db)
        }
        
        loadProjects()
        return project
    }
    
    func deleteProject(id: UUID) throws {
        try DatabaseManager.shared.dbPool.write { db in
            try Project.deleteOne(db, key: ["id": id.uuidString])
        }
        
        if _activeProjectId == id {
            _activeProjectId = nil
        }
        
        loadProjects()
    }
    
    func updateProject(_ project: Project) throws {
        var updatedProject = project
        updatedProject.updatedAt = Date()
        
        try DatabaseManager.shared.dbPool.write { db in
            try updatedProject.update(db)
        }
        
        loadProjects()
    }
    
    func archiveProject(id: UUID) throws {
        guard var project = _projects.first(where: { $0.id == id }) else { return }
        
        project.isArchived = true
        project.isActive = false
        
        if _activeProjectId == id {
            _activeProjectId = nil
        }
        
        try updateProject(project)
    }
    
    // MARK: - Project Mode
    
    func activateProject(id: UUID) throws {
        // Deactivate all other projects first
        try deactivateAllProjects()
        
        // Activate the selected project
        guard var project = _projects.first(where: { $0.id == id }) else { return }
        
        project.isActive = true
        try updateProject(project)
        
        _activeProjectId = id
    }
    
    func deactivateAllProjects() throws {
        try DatabaseManager.shared.dbPool.write { db in
            try db.execute(sql: "UPDATE projects SET isActive = 0 WHERE isActive = 1")
        }
        
        _activeProjectId = nil
        loadProjects()
    }
    
    func exitProjectMode() throws {
        try deactivateAllProjects()
    }
    
    // MARK: - Raw Inputs
    
    func addRawInput(
        projectId: UUID,
        clipboardItemId: UUID,
        sourceContext: String? = nil
    ) throws -> ProjectRawInput {
        let input = ProjectRawInput(
            projectId: projectId,
            clipboardItemId: clipboardItemId,
            sourceContext: sourceContext
        )
        
        print("[ProjectService] Adding raw input for project \(projectId), item: \(clipboardItemId)")
        
        try DatabaseManager.shared.dbPool.write { db in
            try input.insert(db)
            print("[ProjectService] ✅ Raw input inserted: \(input.id)")
        }
        
        // Update project timestamp
        if var project = _projects.first(where: { $0.id == projectId }) {
            project.updatedAt = Date()
            try updateProject(project)
        }
        
        return input
    }
    
    func fetchRawInputs(for projectId: UUID) throws -> [ProjectRawInput] {
        print("[ProjectService] Fetching raw inputs for project: \(projectId)")
        let inputs = try DatabaseManager.shared.dbPool.read { db in
            // Use StatementArguments with the actual UUID object
            return try ProjectRawInput.fetchAll(
                db,
                sql: "SELECT * FROM project_raw_inputs WHERE projectId = ? ORDER BY createdAt DESC",
                arguments: [projectId]
            )
        }
        print("[ProjectService] Found \(inputs.count) raw inputs")
        return inputs
    }
    
    func fetchRawInputsWithItems(for projectId: UUID) throws -> [(input: ProjectRawInput, item: ClipboardItem?)] {
        try DatabaseManager.shared.dbPool.read { db in
            let inputs = try ProjectRawInput.fetchAll(
                db,
                sql: "SELECT * FROM project_raw_inputs WHERE projectId = ? ORDER BY createdAt DESC",
                arguments: [projectId]
            )
            
            print("[ProjectService] Fetched \(inputs.count) raw inputs, now fetching associated items...")
            
            return try inputs.map { input in
                // Use UUID object instead of string for BLOB comparison
                let item = try ClipboardItem.fetchOne(
                    db,
                    sql: "SELECT * FROM clipboard_items WHERE id = ?",
                    arguments: [input.clipboardItemId]
                )
                if item == nil {
                    print("[ProjectService] ⚠️ No clipboard item found for ID: \(input.clipboardItemId)")
                }
                return (input, item)
            }
        }
    }
    
    func deleteRawInput(id: UUID) throws {
        try DatabaseManager.shared.dbPool.write { db in
            try db.execute(
                sql: "DELETE FROM project_raw_inputs WHERE id = ?",
                arguments: [id]
            )
        }
        loadProjects()
    }
    
    func updateRawInputSourceContext(id: UUID, sourceContext: String?) throws {
        try DatabaseManager.shared.dbPool.write { db in
            try db.execute(
                sql: "UPDATE project_raw_inputs SET sourceContext = ? WHERE id = ?",
                arguments: [sourceContext, id]
            )
        }
    }
    
    // MARK: - Cognition
    
    func fetchCurrentCognition(for projectId: UUID) throws -> ProjectCognition? {
        try DatabaseManager.shared.dbPool.read { db in
            // Use SQL with UUID object (not uuidString) for proper BLOB comparison
            guard let project = try Project.fetchOne(
                db,
                sql: "SELECT * FROM projects WHERE id = ?",
                arguments: [projectId]
            ), let cognitionId = project.currentCognitionId else {
                return nil
            }
            
            return try ProjectCognition.fetchOne(
                db,
                sql: "SELECT * FROM project_cognitions WHERE id = ?",
                arguments: [cognitionId]
            )
        }
    }
    
    func fetchCognitionHistory(for projectId: UUID) throws -> [ProjectCognition] {
        try DatabaseManager.shared.dbPool.read { db in
            return try ProjectCognition.fetchAll(
                db,
                sql: "SELECT * FROM project_cognitions WHERE projectId = ? ORDER BY version DESC",
                arguments: [projectId]
            )
        }
    }
    
    func saveCognition(
        projectId: UUID,
        content: String,
        addedInputIds: [UUID] = [],
        changeDescription: String = ""
    ) throws -> ProjectCognition {

        let currentVersion = try DatabaseManager.shared.dbPool.read { db -> Int in
            let count = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM project_cognitions WHERE projectId = ?",
                arguments: [projectId]
            ) ?? 0
            return count + 1
        }

        let cognition = ProjectCognition(
            projectId: projectId,
            content: content,
            version: currentVersion
        )
        
        try DatabaseManager.shared.dbPool.write { db in
            try cognition.insert(db)
            
            // Update project's currentCognitionId
            try db.execute(
                sql: "UPDATE projects SET currentCognitionId = ? WHERE id = ?",
                arguments: [cognition.id, projectId]
            )
            
            // Record change if there's a previous cognition
            if currentVersion > 1,
               let previousCognition = try ProjectCognition.fetchOne(
                   db,
                   sql: "SELECT * FROM project_cognitions WHERE projectId = ? AND version = ?",
                   arguments: [projectId, currentVersion - 1]
               ) {
                let change = ProjectCognitionChange(
                    projectId: projectId,
                    fromCognitionId: previousCognition.id,
                    toCognitionId: cognition.id,
                    changeDescription: changeDescription,
                    addedInputs: addedInputIds
                )
                try change.insert(db)
            }
            
            // Mark raw inputs as analyzed
            for inputId in addedInputIds {
                try db.execute(
                    sql: "UPDATE project_raw_inputs SET isAnalyzed = 1 WHERE id = ?",
                    arguments: [inputId]
                )
            }
        }
        
        loadProjects()
        return cognition
    }
    
    // MARK: - Export
    
    func exportProjectToMarkdown(projectId: UUID, includeRawInputs: Bool = true) throws -> String {
        guard let cognition = try fetchCurrentCognition(for: projectId) else {
            throw ProjectError.noCognitionFound
        }
        
        let rawInputs = try fetchRawInputsWithItems(for: projectId)
        
        var markdown = cognition.content
        
        if includeRawInputs && !rawInputs.isEmpty {
            markdown += "\n\n## 原始素材\n\n"
            markdown += "<details>\n<summary>点击展开原始记录</summary>\n\n"
            
            for (input, item) in rawInputs {
                if let item = item {
                    markdown += "### \(input.sourceContext ?? "未命名") - \(input.createdAt.formatted())\n\n"
                    markdown += "```\n\(item.content)\n```\n\n"
                }
            }
            
            markdown += "</details>\n"
        }
        
        return markdown
    }
    
    // MARK: - Private Methods
    
    private func loadProjects() {
        do {
            _projects = try DatabaseManager.shared.dbPool.read { db in
                try Project.fetchAll(db, sql: "SELECT * FROM projects ORDER BY updatedAt DESC")
            }
            
            // Restore active project if exists
            if let active = _projects.first(where: { $0.isActive }) {
                _activeProjectId = active.id
            }
        } catch {
            print("[ProjectService] Failed to load projects: \(error)")
        }
    }
}

// MARK: - Errors

enum ProjectError: LocalizedError {
    case noCognitionFound
    case projectNotFound
    
    var errorDescription: String? {
        switch self {
        case .noCognitionFound:
            return NSLocalizedString("项目暂无认知文档", comment: "No cognition found error")
        case .projectNotFound:
            return NSLocalizedString("找不到指定项目", comment: "Project not found error")
        }
    }
}
