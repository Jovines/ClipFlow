import SwiftUI

struct HeaderBar: View {
    @Binding var showProjectSelector: Bool
    let currentProject: Project?
    @Binding var isProjectMode: Bool

    var body: some View {
        HStack(spacing: 8) {
            ProjectButton(
                showProjectSelector: $showProjectSelector,
                currentProject: currentProject,
                isProjectMode: $isProjectMode
            )

            Spacer()
        }
        .frame(height: 32)
        .padding(.horizontal, 8)
    }
}

struct ProjectButton: View {
    @Binding var showProjectSelector: Bool
    let currentProject: Project?
    @Binding var isProjectMode: Bool
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        Button {
            showProjectSelector = true
        } label: {
            HStack(spacing: 4) {
                if let project = currentProject {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 10))
                    Text(project.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                } else {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 10))
                    Text("Project".localized())
                        .font(.system(size: 11))
                }
            }
            .foregroundStyle(currentProject != nil ? themeManager.accent : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                currentProject != nil
                    ? themeManager.selectedBackground
                    : themeManager.chromeSurface
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(themeManager.separator, lineWidth: currentProject != nil ? 0 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .help(currentProject == nil ? "Project".localized() : currentProject?.name ?? "Project".localized())
        .accessibilityLabel(currentProject == nil ? "Project".localized() : currentProject?.name ?? "Project".localized())
    }
}
