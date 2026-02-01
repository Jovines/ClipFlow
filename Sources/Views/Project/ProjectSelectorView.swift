import SwiftUI
import AppKit

struct ProjectSelectorView: View {
    @ObservedObject var projectService = ProjectService.shared
    @Binding var isPresented: Bool
    var onSelectProject: (Project) -> Void
    var onCreateProject: () -> Void
    
    @State private var searchText = ""
    
    var filteredProjects: [Project] {
        if searchText.isEmpty {
            return projectService.activeProjects
        }
        return projectService.activeProjects.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("选择项目")
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索项目...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
            .padding(.horizontal)
            
            Divider()
                .padding(.top, 8)
            
            // Project List
            if filteredProjects.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("暂无项目")
                        .foregroundStyle(.secondary)
                    Text("点击下方按钮创建新项目")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredProjects) { project in
                            ProjectRow(
                                project: project,
                                isActive: projectService.activeProjectId == project.id
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelectProject(project)
                                isPresented = false
                            }
                            .contextMenu {
                                Button("归档项目") {
                                    try? projectService.archiveProject(id: project.id)
                                }
                                Button("删除项目", role: .destructive) {
                                    try? projectService.deleteProject(id: project.id)
                                }
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // Create Button
            Button(action: onCreateProject) {
                Label("创建新项目", systemImage: "plus.circle")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding()
        }
        .frame(width: 280, height: 400)
    }
}

struct ProjectRow: View {
    let project: Project
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isActive ? "folder.fill" : "folder")
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: 13, weight: .medium))
                Text(project.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.caption)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
    }
}

struct CreateProjectSheet: View {
    @Binding var isPresented: Bool
    var onCreated: (Project) -> Void
    
    @State private var name = ""
    @State private var description = ""
    @State private var isCreating = false
    
    var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("创建新项目")
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Form
            VStack(alignment: .leading, spacing: 8) {
                Text("项目名称")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("例如：用户登录模块优化", text: $name)
                    .textFieldStyle(.roundedBorder)
                
                Text("项目描述（可选）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                TextEditor(text: $description)
                    .font(.system(size: 13))
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            }
            
            // Buttons
            HStack {
                Button("取消") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Button(action: createProject) {
                    if isCreating {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.8)
                    } else {
                        Text("创建")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!canCreate || isCreating)
            }
        }
        .padding()
        .frame(width: 320)
    }
    
    private func createProject() {
        guard canCreate else { return }
        
        isCreating = true
        
        Task {
            let trimmedDescription = description.isEmpty ? nil : description
            let project = try? ProjectService.shared.createProject(
                name: name,
                description: trimmedDescription
            )
            
            await MainActor.run {
                isCreating = false
                isPresented = false
                
                if let project = project {
                    onCreated(project)
                }
            }
        }
    }
}
