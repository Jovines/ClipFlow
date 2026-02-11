import SwiftUI
import AppKit

struct GroupPanelView: View {
    let panelInfo: PanelInfo?
    let panelItems: [ClipboardItem]
    let clipboardMonitor: ClipboardMonitor
    let onItemSelected: (ClipboardItem) -> Void
    let onItemEdit: (ClipboardItem) -> Void
    let onItemDelete: (ClipboardItem) -> Void
    let onAddToProject: (ClipboardItem) -> Void
    let onHide: () -> Void

    private let panelWidth: CGFloat = 300

    struct PanelInfo {
        let startIndex: Int
        let endIndex: Int
    }

    var body: some View {
        VStack(spacing: 0) {
            groupPanelHeader
            Divider()
            groupPanelContent
            Divider()
            groupPanelFooter
        }
        .frame(width: panelWidth, height: 480)
        .background(ThemeManager.shared.surface.opacity(0.95))
    }

    private var groupPanelHeader: some View {
        HStack {
            if let info = panelInfo {
                Text("Records %1$d-%2$d".localized(info.startIndex, info.endIndex))
                    .font(.system(size: 13, weight: .medium))
            }
            Spacer()
            Text("%1$d items".localized(panelItems.count))
                .font(.caption)
                .foregroundStyle(ThemeManager.shared.textSecondary)
        }
        .frame(height: 32)
        .padding(.horizontal, 12)
    }

    private var groupPanelContent: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(Array(panelItems.enumerated()), id: \.element.id) { index, item in
                    GroupPanelItemRow(
                        item: item,
                        index: index,
                        clipboardMonitor: clipboardMonitor,
                        onSelect: {
                            onItemSelected(item)
                            onHide()
                        },
                        onEdit: { onItemEdit(item) },
                        onDelete: { onItemDelete(item) },
                        onAddToProject: { onAddToProject(item) }
                    )
                }
            }
            .padding(8)
        }
    }

    private var groupPanelFooter: some View {
        HStack {
            Spacer()

            Button(action: onHide) {
                Text("Close".localized())
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
