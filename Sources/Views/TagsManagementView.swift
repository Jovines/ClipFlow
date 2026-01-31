import SwiftUI

struct TagsManagementView: View {
    @State private var tags: [Tag] = []
    @State private var newTagName = ""
    @State private var editingTag: Tag?
    @State private var showEditSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
                Text("Manage Tags")
                    .font(.system(size: 14, weight: .semibold))
            }

            HStack(spacing: 8) {
                TextField("New tag name...", text: $newTagName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.flexokiSurfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.flexokiBorder, lineWidth: 1)
                    )

                Button("Add") {
                    addTag()
                }
                .disabled(newTagName.isEmpty)
                .controlSize(.small)
            }
            .padding(12)
            .background(Color.flexokiSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if tags.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tag.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No tags yet")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("Create tags to organize your clipboard items")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
                .background(Color.flexokiSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 0) {
                    ForEach(tags) { tag in
                        TagRow(
                            tag: tag,
                            onEdit: { editTag(tag) },
                            onDelete: { removeTag(tag) }
                        )

                        if tag.id != tags.last?.id {
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                }
                .padding(8)
                .background(Color.flexokiSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()
        }
        .sheet(isPresented: $showEditSheet) {
            if let tag = editingTag {
                EditTagSheet(tag: tag) { updatedTag in
                    updateTag(tag, with: updatedTag)
                }
            }
        }
        .onAppear {
            loadTags()
        }
    }

    private func loadTags() {
        do {
            tags = try DatabaseManager.shared.fetchAllTags()
        } catch {
            ClipFlowLogger.error("Failed to load tags: \(error)")
            tags = []
        }
    }

    private func addTag() {
        do {
            let tag = try DatabaseManager.shared.createTag(name: newTagName, color: "blue")
            tags.append(tag)
            newTagName = ""
        } catch {
            ClipFlowLogger.error("Failed to add tag: \(error)")
        }
    }

    private func removeTag(_ tag: Tag) {
        do {
            try DatabaseManager.shared.deleteTag(id: tag.id)
            tags.removeAll { $0.id == tag.id }
        } catch {
            ClipFlowLogger.error("Failed to remove tag: \(error)")
        }
    }

    private func editTag(_ tag: Tag) {
        editingTag = tag
        showEditSheet = true
    }

    private func updateTag(_ oldTag: Tag, with newTag: Tag) {
        do {
            try DatabaseManager.shared.updateTagName(id: oldTag.id, name: newTag.name)
            try DatabaseManager.shared.updateTagColor(id: oldTag.id, color: newTag.color)
            if let index = tags.firstIndex(where: { $0.id == oldTag.id }) {
                tags[index] = newTag
            }
        } catch {
            ClipFlowLogger.error("Failed to update tag: \(error)")
        }
    }
}

struct TagRow: View {
    let tag: Tag
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.fromHex(Tag.colorForName(tag.color)))
                .frame(width: 10, height: 10)

            Text(tag.name)
                .font(.system(size: 13))

            Spacer()

            HStack(spacing: 4) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

struct EditTagSheet: View {
    let tag: Tag
    let onSave: (Tag) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedColor: String

    init(tag: Tag, onSave: @escaping (Tag) -> Void) {
        self.tag = tag
        self.onSave = onSave
        _name = State(initialValue: tag.name)
        _selectedColor = State(initialValue: tag.color)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Tag")
                .font(.headline)

            TextField("Tag Name", text: $name)
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.flexokiSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.flexokiBorder, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    ForEach(Tag.availableColors, id: \.name) { color in
                        Circle()
                            .fill(Color.fromHex(color.hex))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: selectedColor == color.name ? 2 : 0)
                            )
                            .onTapGesture {
                                selectedColor = color.name
                            }
                    }
                }
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Save") {
                    let updatedTag = Tag(id: tag.id, name: name, color: selectedColor)
                    onSave(updatedTag)
                    dismiss()
                }
                .disabled(name.isEmpty)
                .keyboardShortcut(KeyEquivalent.return, modifiers: [])
            }
        }
        .padding(24)
        .frame(width: 320, height: 240)
    }
}
