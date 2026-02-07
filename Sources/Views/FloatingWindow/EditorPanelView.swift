import SwiftUI
import AppKit
import Foundation

struct EditorPanelView: View {
    @Binding var editContent: String
    @Binding var editingItem: ClipboardItem?
    let originalContent: String
    let onSave: () -> Void
    let onCancel: () -> Void
    let onReset: () -> Void

    @StateObject private var tagService = TagService.shared
    @State private var itemTags: [Tag] = []

    private let editorWidth: CGFloat = 280
    private let maxCharacterCount = 10000

    private var characterCount: Int {
        editContent.count
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader
            Divider()
            editorContent
            tagSection
            Divider()
            editorFooter
        }
        .frame(width: editorWidth, height: 480)
        .background(ThemeManager.shared.surface.opacity(0.95))
        .onAppear {
            loadItemTags()
        }
        .onChange(of: editingItem) { _, _ in
            loadItemTags()
        }
    }

    private func loadItemTags() {
        guard let item = editingItem else {
            itemTags = []
            return
        }
        do {
            itemTags = try tagService.getTagsForItem(itemId: item.id)
        } catch {
            itemTags = []
        }
    }

    private var editorHeader: some View {
        HStack {
            Text("编辑记录")
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(ThemeManager.shared.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 32)
        .padding(.horizontal, 12)
    }

    private var editorContent: some View {
        VStack(spacing: 0) {
            TextEditor(text: $editContent)
                .font(.system(size: 13))
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color.clear)

            HStack {
                Text("\(characterCount)/\(maxCharacterCount)")
                    .font(.caption)
                    .foregroundStyle(ThemeManager.shared.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()

            Text("标签")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ThemeManager.shared.textSecondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    let availableTags = tagService.allTags.filter { tag in
                        !itemTags.contains(where: { $0.id == tag.id })
                    }

                    if availableTags.isEmpty {
                        Text("所有标签已添加")
                            .font(.system(size: 11))
                            .foregroundStyle(ThemeManager.shared.textSecondary.opacity(0.6))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(Array(availableTags.enumerated()), id: \.element.id) { _, tag in
                            Button(action: { addTag(tag) }) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.hex(tag.color))
                                        .frame(width: 8, height: 8)
                                    Text(tag.name)
                                        .font(.system(size: 12))
                                        .foregroundStyle(ThemeManager.shared.text)
                                    Spacer()
                                    Image(systemName: "plus")
                                        .font(.system(size: 10))
                                        .foregroundStyle(ThemeManager.shared.textSecondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(ThemeManager.shared.surfaceElevated.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 120)

            if !itemTags.isEmpty {
                Divider()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                FlowLayout(spacing: 6) {
                    ForEach(itemTags) { tag in
                        TagChip(tag: tag, onRemove: { removeTag(tag) })
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .frame(maxHeight: 200)
    }

    private func addTag(_ tag: Tag) {
        guard let item = editingItem else { return }
        do {
            try tagService.addTagToItem(itemId: item.id, tagId: tag.id)
            loadItemTags()
            tagService.refreshTags()
        } catch {
            print("[EditorPanelView] Failed to add tag: \(error)")
        }
    }

    private func removeTag(_ tag: Tag) {
        guard let item = editingItem else { return }
        do {
            try tagService.removeTagFromItem(itemId: item.id, tagId: tag.id)
            loadItemTags()
            tagService.refreshTags()
        } catch {
            print("[EditorPanelView] Failed to remove tag: \(error)")
        }
    }

    private var editorFooter: some View {
        HStack(spacing: 8) {
            Button(action: onReset) {
                Text("重置")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .disabled(editContent == originalContent)

            Spacer()

            Button(action: onCancel) {
                Text("取消")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)

            Button(action: onSave) {
                Text("保存")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .disabled(editContent.isEmpty || editContent == originalContent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct TagChip: View {
    let tag: Tag
    let onRemove: (() -> Void)?

    init(tag: Tag, onRemove: (() -> Void)? = nil) {
        self.tag = tag
        self.onRemove = onRemove
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.hex(tag.color))
                .frame(width: 6, height: 6)
            Text(tag.name)
                .font(.system(size: 11))
                .lineLimit(1)

            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.hex(tag.color))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, onRemove != nil ? 6 : 8)
        .padding(.vertical, 4)
        .background(Color.hex(tag.color).opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}
