import SwiftUI

struct TagSidebarView: View {
    @ObservedObject var tagService: TagService
    @Binding var selectedTagIds: [UUID]
    let onManageTags: () -> Void
    @Binding var showTopRecentHistory: Bool
    @State private var editingTag: Tag?
    @State private var editName: String = ""
    @State private var showDeleteConfirmation: Bool = false
    @State private var tagToDelete: Tag?

    private let sidebarWidth: CGFloat = 80

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text("Filter".localized())
                    .font(.system(size: 11, weight: .medium))
                Spacer()
            }
            .frame(height: 32)
            .padding(.horizontal, 8)

            Divider()

            ScrollView {
                VStack(spacing: 4) {
                    TopRecentHistorySidebarItem(
                        isSelected: $showTopRecentHistory,
                        count: tagService.topRecentHistoryCount
                    )
                    .onTapGesture {
                        showTopRecentHistory.toggle()
                    }

                    Divider()
                        .padding(.vertical, 4)

                    ForEach(allTags) { tag in
                        TagSidebarRowView(
                            tag: tag,
                            isSelected: selectedTagIds.contains(tag.id),
                            onTap: { toggleTag(tag.id) },
                            onEdit: { startEdit(tag) },
                            onDelete: { confirmDelete(tag) }
                        )
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
            }

            Divider()

            HStack(spacing: 4) {
                Button(action: onManageTags) {
                    Image(systemName: "tag")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Manage Tags".localized())
            }
            .frame(height: 28)
            .padding(.horizontal, 6)
            .background(ThemeManager.shared.surface)
        }
        .frame(width: sidebarWidth)
        .background(ThemeManager.shared.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .sheet(isPresented: .constant(editingTag != nil)) {
            editTagSheet
        }
        .alert("Delete Tag".localized(), isPresented: $showDeleteConfirmation) {
            Button("Cancel".localized(), role: .cancel) {}
            Button("Delete".localized(), role: .destructive) { deleteTag() }
        } message: {
            if let tag = tagToDelete {
                Text("Are you sure you want to delete \"\(tag.name)\"? This will remove the tag from all clipboard items.".localized())
            }
        }
    }

    private var allTags: [Tag] {
        tagService.allTags
    }

    private func toggleTag(_ tagId: UUID) {
        if let index = selectedTagIds.firstIndex(of: tagId) {
            selectedTagIds.remove(at: index)
        } else {
            selectedTagIds.append(tagId)
        }
    }

    private func startEdit(_ tag: Tag) {
        editingTag = tag
        editName = tag.name
    }

    private func saveEdit() {
        guard let tag = editingTag else { return }
        do {
            try tagService.updateTag(id: tag.id, name: editName, color: tag.color)
            editingTag = nil
            editName = ""
        } catch {
            print("[TagSidebarView] Failed to update tag: \(error)")
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
            selectedTagIds.removeAll { $0 == tag.id }
            tagToDelete = nil
        } catch {
            print("[TagSidebarView] Failed to delete tag: \(error)")
        }
    }

    private var editTagSheet: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Rename Tag".localized())
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

            TextField("Tag name".localized(), text: $editName)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(ThemeManager.shared.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 12)

            Spacer()

            HStack(spacing: 8) {
                Button(action: { editingTag = nil }) {
                    Text("Cancel".localized())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                Button(action: saveEdit) {
                    Text("Save".localized())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .disabled(editName.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(width: 260, height: 160)
        .background(ThemeManager.shared.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TopRecentHistorySidebarItem: View {
    @Binding var isSelected: Bool
    let count: Int

    private var themeManager: ThemeManager { ThemeManager.shared }

    var body: some View {
        Button {
            isSelected.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? themeManager.accent : themeManager.textSecondary)

                Text("Recent History".localized())
                    .font(.system(size: 10))
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
            .background(isSelected ? themeManager.activeBackground : Color.clear)
            .foregroundStyle(isSelected ? themeManager.accent : themeManager.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct TagSidebarRowView: View {
    let tag: Tag
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.hex(tag.color))
                    .frame(width: 6, height: 6)

                Text(tag.name)
                    .font(.system(size: 10))
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
            .background(isSelected ? Color.hex(tag.color).opacity(0.15) : Color.clear)
            .foregroundStyle(isSelected ? Color.hex(tag.color) : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onEdit) {
                Label("Rename".localized(), systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete".localized(), systemImage: "trash")
            }
        }
    }
}
