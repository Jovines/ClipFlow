import SwiftUI
import AppKit

struct AddToProjectSelectorView: View {
    @ObservedObject var projectService = ProjectService.shared
    @Binding var isPresented: Bool
    let clipboardItem: ClipboardItem
    let onAdded: () -> Void

    @State private var searchText = ""
    @State private var isAdding = false

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
                Text("添加到项目")
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

            // Content Preview
            HStack(spacing: 8) {
                Image(systemName: clipboardItem.contentType == .text ? "doc.text" : "photo")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                Text(clipboardItem.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
            .padding(.horizontal)

            Divider()
                .padding(.top, 8)

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
            .padding(.top, 8)

            // Project List
            if filteredProjects.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("暂无项目")
                        .foregroundStyle(.secondary)
                    Text("请先在设置中创建项目")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredProjects) { project in
                            AddToProjectRow(
                                project: project,
                                isAdding: isAdding
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                addToProject(project: project)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 280, height: 400)
    }

    private func addToProject(project: Project) {
        guard !isAdding else { return }
        isAdding = true

        Task {
            do {
                _ = try projectService.addRawInput(
                    projectId: project.id,
                    clipboardItemId: clipboardItem.id
                )

                await MainActor.run {
                    isPresented = false
                    onAdded()
                }
            } catch {
                await MainActor.run {
                    isAdding = false
                    ClipFlowLogger.error("Failed to add to project: \(error)")
                }
            }
        }
    }
}

struct AddToProjectRow: View {
    let project: Project
    let isAdding: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: 13, weight: .medium))
                Text(project.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isAdding {
                ProgressView()
                    .scaleEffect(0.6)
            } else {
                Image(systemName: "plus.circle")
                    .foregroundStyle(Color.accentColor)
                    .font(.caption)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .opacity(isAdding ? 0.6 : 1)
    }
}
