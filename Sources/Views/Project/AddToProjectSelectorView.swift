import SwiftUI
import AppKit

struct AddToProjectSelectorView: View {
    @ObservedObject var projectService = ProjectService.shared
    @Binding var isPresented: Bool
    let clipboardItem: ClipboardItem
    let onAdded: () -> Void

    @State private var searchText = ""
    @State private var isAdding = false
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
                Text("Add to Project".localized())
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

            // Content Preview
            HStack(spacing: 8) {
                Image(systemName: previewIcon)
                    .foregroundStyle(.secondary)
                    .font(.caption)

                if let richTextFormat = clipboardItem.richTextFormatLabel {
                    AddToProjectRichTextBadge(format: richTextFormat)
                }

                Text(previewText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(ThemeManager.shared.borderSubtle)
            .cornerRadius(6)
            .padding(.horizontal)

            Divider()
                .padding(.top, 8)

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
                        Text("Please create a project in settings first".localized())
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
        .alert("Operation Failed".localized(), isPresented: $showErrorAlert) {
            Button("OK".localized()) {}
        } message: {
            Text(errorMessage)
        }
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
                    showError(message: "Failed to add item to project: %1$@".localized(error.localizedDescription))
                }
            }
        }
    }

    private func showError(message: String) {
        errorMessage = message
        showErrorAlert = true
    }

    private var previewIcon: String {
        clipboardItem.displayIconName
    }

    private var previewText: String {
        switch clipboardItem.contentType {
        case .text, .image:
            return clipboardItem.content
        case .file:
            return clipboardItem.fileDisplayText
        }
    }
}

private struct AddToProjectRichTextBadge: View {
    let format: String

    private var themeManager: ThemeManager { ThemeManager.shared }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 8, weight: .semibold))

            Text(format.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(themeManager.textSecondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(themeManager.chromeSurfaceElevated.opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(themeManager.separator.opacity(0.9), lineWidth: 1)
        )
    }

    private var iconName: String {
        switch format.uppercased() {
        case "HTML":
            return "curlybraces"
        case "RTF":
            return "textformat"
        default:
            return "doc.richtext"
        }
    }
}

struct AddToProjectRow: View {
    let project: Project
    let isAdding: Bool

    private var absoluteDateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: project.updatedAt)
    }

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
                    .foregroundStyle(Color.flexokiAccent)
                    .font(.caption)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .opacity(isAdding ? 0.6 : 1)
        .help(absoluteDateText)
    }
}
