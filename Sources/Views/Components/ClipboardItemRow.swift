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
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(previewText)
                    .font(.body)
                    .lineLimit(2)

                HStack {
                    Text(formatTimeAgo(from: item.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !currentTags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(currentTags.prefix(3)) { tag in
                                Text(tag.name)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.flexokiTagColor(for: tag.color).opacity(0.2))
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
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .padding(12)
        .background(isHovered ? Color.flexokiAccent.opacity(0.15) : Color.clear)
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

    private func formatTimeAgo(from date: Date) -> String {
        let now = Date()
        let elapsed = now.timeIntervalSince(date)

        if elapsed < 60 {
            return "刚刚"
        } else if elapsed < 120 {
            return "1 分钟前"
        } else if elapsed < 180 {
            return "2 分钟前"
        } else if elapsed < 240 {
            return "3 分钟前"
        } else if elapsed < 300 {
            return "4 分钟前"
        } else if elapsed < 600 {
            return "5 分钟前"
        } else if elapsed < 900 {
            return "10 分钟前"
        } else if elapsed < 1200 {
            return "15 分钟前"
        } else if elapsed < 1800 {
            return "20 分钟前"
        } else if elapsed < 3600 {
            return "半小时前"
        } else if elapsed < 7200 {
            return "1 小时前"
        } else if elapsed < 86400 {
            let hours = Int(elapsed / 3600)
            return "\(hours) 小时前"
        } else {
            let days = Int(elapsed / 86400)
            return "\(days) 天前"
        }
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
                                    .fill(Color.flexokiTagColor(for: tag.color))
                                    .frame(width: 12, height: 12)
                                Text(tag.name)
                                Spacer()
                                if currentTags.contains(where: { $0.id == tag.id }) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.flexokiAccent)
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
        do {
            availableTags = try DatabaseManager.shared.fetchAllTags()
        } catch {
            availableTags = []
        }
    }

    private func addNewTag() {
        do {
            let tag = try DatabaseManager.shared.createTag(name: newTagName, color: "blue")
            availableTags.append(tag)
            newTagName = ""
        } catch {
            print("Failed to add tag: \(error)")
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
        do {
            let tagIds = currentTags.map { $0.id }
            try DatabaseManager.shared.updateItemTags(itemId: item.id, tagIds: tagIds)
        } catch {
            print("Failed to update item tags: \(error)")
        }
    }
}

#Preview {
    ClipboardItemRow(item: ClipboardItem(
        content: "Hello, World!",
        contentType: .text
    ))
    .padding()
}
