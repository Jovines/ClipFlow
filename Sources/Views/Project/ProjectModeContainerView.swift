import SwiftUI

struct ProjectModeContainerView: View {
    let project: Project
    let onClose: () -> Void
    let onExitProject: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Left: Project Mode View
            ProjectModeView(
                project: project,
                onExit: onExitProject
            )
            .frame(width: 680)
        }
        .background(Color.flexokiSurface.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 5)
    }
}
