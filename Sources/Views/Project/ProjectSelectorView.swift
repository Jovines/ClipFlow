import SwiftUI
import AppKit

struct ProjectSelectorView: View {
    @ObservedObject var projectService = ProjectService.shared
    @Binding var isPresented: Bool
    var onSelectProject: (Project) -> Void
    var onCreateProject: () -> Void
    
    @State private var searchText = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
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
                .accessibilityLabel("Close".localized())
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

                    if searchText.isEmpty {
                        Text("No Projects".localized())
                            .foregroundStyle(.secondary)
                        Text("Tap the button below to create a new project".localized())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No matching projects".localized())
                            .foregroundStyle(.secondary)
                        Button("Clear Search".localized()) {
                            searchText = ""
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
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
                                    archiveProject(project)
                                }
                                Button("Project Delete".localized(), role: .destructive) {
                                    deleteProject(project)
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
        .alert("Operation Failed".localized(), isPresented: $showErrorAlert) {
            Button("OK".localized()) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func archiveProject(_ project: Project) {
        do {
            try projectService.archiveProject(id: project.id)
        } catch {
            showError(message: "Failed to archive project: %1$@".localized(error.localizedDescription))
        }
    }

    private func deleteProject(_ project: Project) {
        do {
            try projectService.deleteProject(id: project.id)
        } catch {
            showError(message: "Failed to delete project: %1$@".localized(error.localizedDescription))
        }
    }

    private func showError(message: String) {
        errorMessage = message
        showErrorAlert = true
    }
}

struct ProjectRow: View {
    let project: Project
    let isActive: Bool
    @StateObject private var themeManager = ThemeManager.shared

    private var absoluteDateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: project.updatedAt)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isActive ? "folder.fill" : "folder")
                .foregroundStyle(isActive ? themeManager.accent : themeManager.textSecondary)
            
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
                    .foregroundStyle(themeManager.accent)
                    .font(.caption)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(isActive ? themeManager.accent.opacity(0.1) : Color.clear)
        .help(absoluteDateText)
    }
}

struct CreateProjectSheet: View {
    @Binding var isPresented: Bool
    var onCreated: (Project) -> Void
    
    @State private var name = ""
    @State private var description = ""
    @State private var isCreating = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
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
        .alert("Operation Failed".localized(), isPresented: $showErrorAlert) {
            Button("OK".localized()) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func createProject() {
        guard canCreate else { return }
        
        isCreating = true
        
        Task {
            let trimmedDescription = description.isEmpty ? nil : description
            do {
                let project = try ProjectService.shared.createProject(
                    name: name,
                    description: trimmedDescription
                )

                await MainActor.run {
                    isCreating = false
                    isPresented = false
                    onCreated(project)
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = "Failed to create project: %1$@".localized(error.localizedDescription)
                    showErrorAlert = true
                }
            }
        }
    }
}
