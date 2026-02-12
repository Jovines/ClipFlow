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
                Text("Select Project".localized())
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
                TextField("Search projects...".localized(), text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(ThemeManager.shared.borderSubtle)
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
                    Text("No Projects".localized())
                        .foregroundStyle(.secondary)
                    Text("Tap the button below to create a new project".localized())
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
                                Button("Project Archive".localized()) {
                                    try? projectService.archiveProject(id: project.id)
                                }
                                Button("Project Delete".localized(), role: .destructive) {
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
                Label("Create New Project".localized(), systemImage: "plus.circle")
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
                .foregroundStyle(isActive ? Color.flexokiAccent : ThemeManager.shared.textSecondary)
            
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
                    .foregroundStyle(Color.flexokiAccent)
                    .font(.caption)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(isActive ? Color.flexokiAccent.opacity(0.1) : Color.clear)
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
                Text("Create New Project".localized())
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
                Text("Project Name".localized())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Project Name Placeholder".localized(), text: $name)
                    .textFieldStyle(.roundedBorder)
                
                Text("Project Description (Optional)".localized())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                TextEditor(text: $description)
                    .font(.system(size: 13))
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(ThemeManager.shared.borderSubtle, lineWidth: 1)
                    )
            }
            
            // Buttons
            HStack {
                Button("Cancel".localized()) {
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
                        Text("Create".localized())
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
