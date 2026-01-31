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
    
    @Binding var allTags: [Tag]
    @Binding var itemTags: [Tag]
    let onTagsChanged: ([Tag]) -> Void

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
            Divider()
            tagSection
            Divider()
            editorFooter
        }
        .frame(width: editorWidth, height: 420)
        .background(Color.flexokiSurface.opacity(0.95))
    }

    private var editorHeader: some View {
        HStack {
            Text("编辑记录")
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.flexokiTextSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
                    .foregroundStyle(Color.flexokiTextSecondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }
    
    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("标签")
                    .font(.system(size: 12, weight: .medium))
                
                Spacer()
                
                if !allTags.isEmpty {
                    Text("\(itemTags.count)/\(allTags.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if allTags.isEmpty {
                Text("暂无标签，请先在设置中创建")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    FlowLayout(spacing: 6) {
                        ForEach(allTags) { tag in
                            TagToggleChip(
                                tag: tag,
                                isSelected: isTagSelected(tag)
                            ) {
                                toggleTag(tag)
                            }
                        }
                    }
                }
                .frame(maxHeight: 100)
            }
            
            createNewTagSection
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private var createNewTagSection: some View {
        HStack(spacing: 8) {
            TextField("新建标签...", text: $newTagName)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.flexokiSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.flexokiBorder, lineWidth: 1)
                )
                .focused($isInputFocused)
                .onSubmit {
                    createNewTag()
                }
            
            Button(action: createNewTag) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.flexokiAccent)
            }
            .buttonStyle(.plain)
            .disabled(newTagName.isEmpty)
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
    
    private func isTagSelected(_ tag: Tag) -> Bool {
        itemTags.contains(where: { $0.id == tag.id })
    }
    
    private func toggleTag(_ tag: Tag) {
        ClipFlowLogger.info("Toggling tag: \(tag.name), currently selected: \(isTagSelected(tag))")
        if let index = itemTags.firstIndex(where: { $0.id == tag.id }) {
            itemTags.remove(at: index)
            ClipFlowLogger.info("Removed tag: \(tag.name), remaining tags: \(itemTags.count)")
        } else {
            itemTags.append(tag)
            ClipFlowLogger.info("Added tag: \(tag.name), total tags: \(itemTags.count)")
        }
        onTagsChanged(itemTags)
    }
    
    private func createNewTag() {
        guard !newTagName.isEmpty else { return }
        
        do {
            let newTag = try DatabaseManager.shared.createTag(name: newTagName, color: "blue")
            allTags.append(newTag)
            itemTags.append(newTag)
            newTagName = ""
            onTagsChanged(itemTags)
        } catch {
            ClipFlowLogger.error("Failed to create tag: \(error)")
        }
    }
    
    @State private var newTagName: String = ""
    @FocusState private var isInputFocused: Bool
}

struct TagToggleChip: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.flexokiTagColor(for: tag.color))
                    .frame(width: 6, height: 6)
                
                Text(tag.name)
                    .font(.system(size: 10))
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.flexokiTagColor(for: tag.color).opacity(0.25)
        }
        return Color.flexokiSurfaceElevated
    }
    
    private var foregroundColor: Color {
        if isSelected {
            return Color.flexokiTagColor(for: tag.color)
        }
        return Color.flexokiText
    }
}
