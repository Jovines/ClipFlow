import SwiftUI

struct ProjectModeBar: View {
    @ObservedObject var projectService: ProjectService
    @Binding var isProjectMode: Bool
    @Binding var currentProject: Project?
    @Binding var showProjectSelector: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            if let project = currentProject {
                // Has current project - show based on mode
                if isProjectMode {
                    // Active Project Mode
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.accentColor)
                        
                        Text(project.name)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Button(action: { 
                            showProjectSelector = true 
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.borderless)
                        
                        Button(action: {
                            isProjectMode = false
                            currentProject = nil
                            // Sync to ProjectService
                            try? ProjectService.shared.exitProjectMode()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
                } else {
                    // Has project but not in project mode - show enter button
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        
                        Text(project.name)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Button(action: {
                            isProjectMode = true
                        }) {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.right.circle")
                                    .font(.system(size: 10))
                                Text("进入")
                                    .font(.system(size: 10))
                            }
                            .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.borderless)
                        
                        Button(action: {
                            currentProject = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
                }
            } else {
                // No Active Project
                Button(action: { showProjectSelector = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 10))
                        Text("项目")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            
            Spacer()
        }
    }
}

struct ProjectQuickSelector: View {
    @ObservedObject var projectService: ProjectService
    @Binding var isPresented: Bool
    var onSelect: (Project) -> Void
    var onCreate: () -> Void
    
    var recentProjects: [Project] {
        Array(projectService.activeProjects.prefix(5))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("快速选择")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 4)
            
            // Recent Projects
            if recentProjects.isEmpty {
                Text("暂无项目")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
            } else {
                ForEach(recentProjects) { project in
                    Button(action: {
                        onSelect(project)
                        isPresented = false
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text(project.name)
                                .font(.system(size: 11))
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color.clear)
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Actions
            HStack(spacing: 12) {
                Button(action: onCreate) {
                    Label("新建", systemImage: "plus")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Button(action: {
                    // Open full project selector
                    isPresented = false
                }) {
                    Text("全部")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
        .frame(width: 160)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .shadow(radius: 4)
    }
}
