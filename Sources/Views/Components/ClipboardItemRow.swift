import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem
    @State private var isHovered = false
    @State private var showingTagSheet = false
    @State private var currentTags: [Tag]

    init(item: ClipboardItem) {
        self.item = item
        _currentTags = State(initialValue: item.tags)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(previewText)
                    .font(.body)
                    .lineLimit(2)

                HStack {
                    Text(item.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !currentTags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(currentTags.prefix(3)) { tag in
                                Text(tag.name)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.fromHex(tag.color).opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: { showingTagSheet = true }) {
                    Image(systemName: "tag")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button(action: { copyItem() }) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
            }
            .opacity(isHovered ? 1 : 0)
        }
        .padding(12)
        .background(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.3) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering in
            isHovered = hovering
        }
        .sheet(isPresented: $showingTagSheet) {
            TagSelectionSheet(item: item, currentTags: $currentTags)
        }
    }

    private var iconName: String {
        switch item.contentType {
        case .text:
            return "doc.text"
        case .image:
            return "photo"
        }
    }

    private var previewText: String {
        switch item.contentType {
        case .text:
            return item.content
        case .image:
            return "Image"
        }
    }

    private func copyItem() {
        ClipboardMonitor.shared.copyToClipboard(item)
    }
}

struct TagSelectionSheet: View {
    let item: ClipboardItem
    @Binding var currentTags: [Tag]
    @Environment(\.dismiss) private var dismiss
    @State private var availableTags: [Tag] = []
    @State private var newTagName = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Manage Tags")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal)

            Divider()

            HStack {
                TextField("New tag...", text: $newTagName)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    addNewTag()
                }
                .disabled(newTagName.isEmpty)
            }
            .padding(.horizontal)

            if availableTags.isEmpty {
                Text("No tags available")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(availableTags.enumerated()), id: \.element.id) { index, tag in
                            HStack {
                                Circle()
                                    .fill(Color.fromHex(tag.color))
                                    .frame(width: 12, height: 12)
                                Text(tag.name)
                                Spacer()
                                if currentTags.contains(where: { $0.id == tag.id }) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .onTapGesture {
                                toggleTag(tag)
                            }
                            
                            if index < availableTags.count - 1 {
                                Divider()
                                    .padding(.leading, 32)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .frame(width: 300, height: 400)
        .padding(.top)
        .onAppear {
            loadAvailableTags()
        }
    }

    private func loadAvailableTags() {
        let tagEntities = PersistenceController.shared.fetchAllTags()
        availableTags = tagEntities.compactMap { entity -> Tag? in
            guard let name = entity.value(forKey: "name") as? String,
                  let color = entity.value(forKey: "color") as? String,
                  let id = entity.value(forKey: "id") as? UUID else {
                return nil
            }
            return Tag(id: id, name: name, color: color)
        }
    }

    private func addNewTag() {
        let entity = PersistenceController.shared.createTag(name: newTagName, color: "blue")
        if let tag = mapTagEntity(entity) {
            availableTags.append(tag)
            newTagName = ""
        }
    }

    private func toggleTag(_ tag: Tag) {
        if let index = currentTags.firstIndex(where: { $0.id == tag.id }) {
            currentTags.remove(at: index)
        } else {
            currentTags.append(tag)
        }
        updateItemTags()
    }

    private func updateItemTags() {
        if let entity = PersistenceController.shared.fetchClipboardItem(by: item.id) {
            PersistenceController.shared.updateItemTags(entity, tags: currentTags)
        }
    }

    private func mapTagEntity(_ entity: NSManagedObject) -> Tag? {
        guard let name = entity.value(forKey: "name") as? String,
              let color = entity.value(forKey: "color") as? String,
              let id = entity.value(forKey: "id") as? UUID else {
            return nil
        }
        return Tag(id: id, name: name, color: color)
    }
}

#Preview {
    ClipboardItemRow(item: ClipboardItem(
        content: "Hello, World!",
        contentType: .text
    ))
    .padding()
}
