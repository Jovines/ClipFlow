import SwiftUI
import AppKit
import Foundation

struct EditorPanelView: View {
    @Binding var editContent: String
    @Binding var editNote: String
    @Binding var editingItem: ClipboardItem?
    let originalContent: String
    let originalNote: String
    let onSave: () -> Void
    let onCancel: () -> Void
    let onReset: () -> Void

    @StateObject private var tagService = TagService.shared
    @State private var itemTags: [Tag] = []
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    private let editorWidth: CGFloat = 280
    private let fixedHeight: CGFloat = 480
    private let maxCharacterCount = 10000
    private let maxNoteCharacterCount = 200

    private var characterCount: Int {
        editContent.count
    }

    private var noteCharacterCount: Int {
        editNote.count
    }

    private var hasChanges: Bool {
        editContent != originalContent || editNote != originalNote
    }

    private var isImageItem: Bool {
        editingItem?.contentType == .image
    }

    private var availableTags: [Tag] {
        tagService.allTags.filter { tag in
            !itemTags.contains(where: { $0.id == tag.id })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader
            Divider()
            editorContent
            if !isImageItem {
                noteSection
                tagSection
            }
            Divider()
            editorFooter
        }
        .frame(width: editorWidth, height: fixedHeight)
        .background(ThemeManager.shared.chromeSurface)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(ThemeManager.shared.separator)
                .frame(width: 1)
        }
        .onAppear {
            loadItemTags()
        }
        .onChange(of: editingItem) { _, _ in
            loadItemTags()
        }
        .alert("Operation Failed".localized(), isPresented: $showErrorAlert) {
            Button("OK".localized()) {}
        } message: {
            Text(errorMessage)
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
            Text(isImageItem ? "Image Preview".localized() : "Edit Record".localized())
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(ThemeManager.shared.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close".localized())
            .help("Close".localized())
        }
        .frame(height: 32)
        .padding(.horizontal, 12)
    }

    private var editorContent: some View {
        GeometryReader { _ in
            if isImageItem {
                imagePreviewContent
            } else {
                VStack(spacing: 0) {
                    TextEditor(text: $editContent)
                        .font(.system(size: 13))
                        .padding(8)
                        .frame(minHeight: 80)
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
        }
        .frame(maxHeight: .infinity)
    }

    private var imagePreviewContent: some View {
        ZStack {
            ThemeManager.shared.chromeSurface.opacity(0.35)

            if let imageData = previewImageData,
               let nsImage = NSImage(data: imageData) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.98))
                    .overlay(
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .padding(8)
                    )
                    .padding(12)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundStyle(ThemeManager.shared.textSecondary)
                    Text("Unable to load image".localized())
                        .font(.system(size: 12))
                        .foregroundStyle(ThemeManager.shared.textSecondary)
                }
            }
        }
    }

    private var previewImageData: Data? {
        guard let item = editingItem else { return nil }

        if let imagePath = item.imagePath,
           let imageData = ImageCacheManager.shared.loadImage(forKey: imagePath) {
            return imageData
        }

        if let thumbnailPath = item.thumbnailPath {
            return ImageCacheManager.shared.loadImage(forKey: thumbnailPath)
        }

        return nil
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "note.text")
                    .font(.system(size: 11))
                    .foregroundStyle(ThemeManager.shared.textSecondary)
                Text("Note".localized())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ThemeManager.shared.textSecondary)
                Spacer()
            }

            TextField("Add Note".localized(), text: $editNote, axis: .vertical)
                .font(.system(size: 12))
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .scrollContentBackground(.hidden)
                .liquidGlassBackground(cornerRadius: 10, material: .thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(ThemeManager.shared.separator, lineWidth: 1)
                )

            if noteCharacterCount > 0 {
                Text("\(noteCharacterCount)/\(maxNoteCharacterCount)")
                    .font(.caption2)
                    .foregroundStyle(ThemeManager.shared.textSecondary.opacity(0.6))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var tagSection: some View {
        Group {
            if tagService.allTags.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "tag")
                            .font(.system(size: 11))
                            .foregroundStyle(ThemeManager.shared.textSecondary)
                        Text("Tags".localized())
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ThemeManager.shared.textSecondary)
                        Spacer()
                    }

                    if !itemTags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(itemTags) { tag in
                                TagChip(tag: tag, onRemove: { removeTag(tag) })
                            }
                        }
                        .padding(.bottom, 4)
                    }

                    let availableTags = tagService.allTags.filter { tag in
                        !itemTags.contains(where: { $0.id == tag.id })
                    }

                    if !availableTags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(availableTags) { tag in
                                Button(action: { addTag(tag) }) {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.hex(tag.color))
                                            .frame(width: 8, height: 8)
                                        Text(tag.name)
                                            .font(.system(size: 11))
                                    }
                                    .foregroundStyle(ThemeManager.shared.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(ThemeManager.shared.textSecondary.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
    }

    private func addTag(_ tag: Tag) {
        guard let item = editingItem else { return }
        do {
            try tagService.addTagToItem(itemId: item.id, tagId: tag.id)
            loadItemTags()
            tagService.refreshTags()
        } catch {
            presentError("Failed to add tag: %1$@".localized(error.localizedDescription))
        }
    }

    private func removeTag(_ tag: Tag) {
        guard let item = editingItem else { return }
        do {
            try tagService.removeTagFromItem(itemId: item.id, tagId: tag.id)
            loadItemTags()
            tagService.refreshTags()
        } catch {
            presentError("Failed to remove tag: %1$@".localized(error.localizedDescription))
        }
    }

    private func presentError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }

    @ViewBuilder
    private var editorFooter: some View {
        if isImageItem {
            HStack {
                Spacer()
                Button(action: onCancel) {
                    Text("Close".localized())
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        } else {
            HStack(spacing: 8) {
                Button(action: onReset) {
                    Text("Reset".localized())
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .disabled(!hasChanges)

                Spacer()

                Button(action: onCancel) {
                    Text("Cancel".localized())
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)

                Button(action: onSave) {
                    Text("Save".localized())
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .disabled(editContent.isEmpty || !hasChanges)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
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
                .fill(Color.hex(tag.color).opacity(ThemeManager.shared.tagTintOpacity))
                .frame(width: 7, height: 7)
            Text(tag.name)
                .font(.system(size: 11))
                .lineLimit(1)
                .foregroundStyle(ThemeManager.shared.text)

            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(ThemeManager.shared.iconSecondary)
                        .frame(width: 16, height: 16)
                        .background(ThemeManager.shared.iconBadgeBackground)
                        .overlay(
                            Circle()
                                .stroke(ThemeManager.shared.iconBadgeStroke, lineWidth: 1)
                        )
                        .clipShape(Circle())
                        .shadow(color: ThemeManager.shared.iconBadgeBackground.opacity(ThemeManager.shared.iconBadgeShadowOpacity), radius: 2, y: 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove Tag".localized())
            }
        }
        .padding(.horizontal, onRemove != nil ? 6 : 8)
        .padding(.vertical, 4)
        .background(Color.hex(tag.color).opacity(ThemeManager.shared.tagFillOpacity))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(ThemeManager.shared.separator, lineWidth: 1)
        )
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
