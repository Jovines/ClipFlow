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
            .foregroundStyle(currentProject != nil ? Color.flexokiAccent : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                currentProject != nil
                    ? Color.flexokiAccent.opacity(0.1)
                    : ThemeManager.shared.surface
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}
