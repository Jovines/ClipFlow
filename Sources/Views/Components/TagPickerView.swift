import SwiftUI

struct TagPickerView: View {
    let item: ClipboardItem
    @ObservedObject var tagService: TagService
    @Environment(\.dismiss) private var dismiss
    @State private var newTagName: String = ""
    @State private var showCreateTag: Bool = false
    @State private var itemTagsData: [Tag] = []
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Manage Tags")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if !itemTags.isEmpty {
                        Text("Attached")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        ForEach(itemTags) { tag in
                            TagRowView(
                                tag: tag,
                                isAttached: true,
                                onToggle: { toggleTag(tag.id) }
                            )
                        }
                    }

                    Text("Available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.top, itemTags.isEmpty ? 0 : 8)

                    ForEach(availableTags) { tag in
                        TagRowView(
                            tag: tag,
                            isAttached: false,
                            onToggle: { toggleTag(tag.id) }
                        )
                    }

                    if showCreateTag {
                        createTagView
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
        }
        .frame(width: 220, height: 280)
        .background(Color.flexokiSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { loadTags() }
    }

    private var itemTags: [Tag] {
        itemTagsData
    }

    private var availableTags: [Tag] {
        let itemTagIds = Set(itemTagsData.map { $0.id })
        return tagService.allTags.filter { !itemTagIds.contains($0.id) }
    }

    private func loadTags() {
        isLoading = true
        do {
            itemTagsData = try tagService.getTagsForItem(itemId: item.id)
        } catch {
            itemTagsData = []
        }
        isLoading = false
    }

    private var createTagView: some View {
        VStack(spacing: 6) {
                TextField("Tag name", text: $newTagName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.flexokiBase150)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack(spacing: 4) {
                ForEach(Tag.availableColors, id: \.hex) { colorOption in
                    Circle()
                        .fill(Color.hex(colorOption.hex))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.flexokiBorder, lineWidth: 1)
                        )
                        .onTapGesture {
                            createTag(colorName: colorOption.name)
                        }
                }
            }
        }
        .padding(8)
        .background(Color.flexokiBase200.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func toggleTag(_ tagId: UUID) {
        do {
            try tagService.toggleTagOnItem(itemId: item.id, tagId: tagId)
            tagService.refreshTags()
            loadTags()
        } catch {
            print("[TagPickerView] Failed to toggle tag: \(error)")
        }
    }

    private func createTag(colorName: String) {
        guard !newTagName.isEmpty else { return }
        do {
            _ = try tagService.createTag(name: newTagName, color: Tag.colorForName(colorName))
            newTagName = ""
            showCreateTag = false
        } catch {
            print("[TagPickerView] Failed to create tag: \(error)")
        }
    }
}

struct TagRowView: View {
    let tag: Tag
    let isAttached: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.hex(tag.color))
                .frame(width: 8, height: 8)

            Text(tag.name)
                .font(.system(size: 12))

            Spacer()

            Image(systemName: isAttached ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundStyle(isAttached ? Color.hex(tag.color) : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isAttached ? Color.hex(tag.color).opacity(0.1) : Color.flexokiSurface)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}
