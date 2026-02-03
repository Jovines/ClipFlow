import SwiftUI

struct TagManagementView: View {
    @ObservedObject var tagService: TagService
    @Environment(\.dismiss) private var dismiss
    @State private var editingTag: Tag?
    @State private var editName: String = ""
    @State private var editColorName: String = "blue"
    @State private var showDeleteConfirmation: Bool = false
    @State private var tagToDelete: Tag?

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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if tagService.allTags.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(tagService.allTags) { tag in
                            TagManagementRowView(
                                tag: tag,
                                onEdit: { startEdit(tag) },
                                onDelete: { confirmDelete(tag) }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
            }

            Divider()

            HStack(spacing: 8) {
                TextField("New tag name", text: $editName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.flexokiBase200)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Menu {
                    ForEach(Tag.availableColors, id: \.name) { colorOption in
                        Button(action: { editColorName = colorOption.name }) {
                            HStack {
                                Circle()
                                    .fill(Color.hex(colorOption.hex))
                                    .frame(width: 12, height: 12)
                                Text(colorOption.name.capitalized)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.hex(Tag.colorForName(editColorName)))
                            .frame(width: 12, height: 12)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.flexokiBase200)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Button(action: createTag) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .disabled(editName.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: 280, height: 360)
        .background(Color.flexokiSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: .constant(editingTag != nil)) {
            editTagSheet
        }
        .alert("Delete Tag", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteTag() }
        } message: {
            if let tag = tagToDelete {
                Text("Are you sure you want to delete \"\(tag.name)\"? This will remove the tag from all clipboard items.")
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tag")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text("No tags yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Create a tag to organize your clipboard items")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var editTagSheet: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Edit Tag")
                    .font(.headline)
                Spacer()
                Button(action: { editingTag = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Divider()

            TextField("Tag name", text: $editName)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.flexokiBase200)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 6) {
                Text("Color")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                HStack(spacing: 8) {
                    ForEach(Tag.availableColors, id: \.name) { colorOption in
                        Circle()
                            .fill(Color.hex(colorOption.hex))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.flexokiBorder, lineWidth: editColorName == colorOption.name ? 2 : 0)
                            )
                            .onTapGesture {
                                editColorName = colorOption.name
                            }
                    }
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            HStack(spacing: 8) {
                Button(action: { editingTag = nil }) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                Button(action: saveEdit) {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .disabled(editName.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(width: 260, height: 220)
        .background(Color.flexokiSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func startEdit(_ tag: Tag) {
        editingTag = tag
        editName = tag.name
        editColorName = Tag.nameForColor(tag.color)
    }

    private func saveEdit() {
        guard let tag = editingTag else { return }
        do {
            try tagService.updateTag(id: tag.id, name: editName, color: Tag.colorForName(editColorName))
            editingTag = nil
            editName = ""
        } catch {
            print("[TagManagementView] Failed to update tag: \(error)")
        }
    }

    private func confirmDelete(_ tag: Tag) {
        tagToDelete = tag
        showDeleteConfirmation = true
    }

    private func deleteTag() {
        guard let tag = tagToDelete else { return }
        do {
            try tagService.deleteTag(id: tag.id)
            tagToDelete = nil
        } catch {
            print("[TagManagementView] Failed to delete tag: \(error)")
        }
    }

    private func createTag() {
        guard !editName.isEmpty else { return }
        do {
            _ = try tagService.createTag(name: editName, color: Tag.colorForName(editColorName))
            editName = ""
        } catch {
            print("[TagManagementView] Failed to create tag: \(error)")
        }
    }
}

struct TagManagementRowView: View {
    let tag: Tag
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.hex(tag.color))
                .frame(width: 10, height: 10)

            Text(tag.name)
                .font(.system(size: 12))

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.flexokiBase200.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
