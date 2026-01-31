import SwiftUI

struct TagSelectorView: View {
    let allTags: [Tag]
    @Binding var selectedTags: [Tag]
    let onTagsChanged: () -> Void
    let onDismiss: () -> Void
    
    @State private var newTagName: String = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            selectorHeader
            
            Divider()
            
            if allTags.isEmpty {
                emptyTagsView
            } else {
                tagsGrid
            }
            
            Divider()
            
            createNewTagSection
            
            Divider()
            
            doneButton
        }
        .frame(width: 280)
        .background(Color.flexokiSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var selectorHeader: some View {
        HStack {
            Text("管理标签")
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.flexokiTextSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    private var emptyTagsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tag.slash")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("暂无标签")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(.vertical, 16)
    }
    
    private var tagsGrid: some View {
        ScrollView {
            FlowLayout(spacing: 8) {
                ForEach(allTags) { tag in
                    TagChip(
                        tag: tag,
                        isSelected: isTagSelected(tag)
                    ) {
                        toggleTag(tag)
                    }
                }
            }
            .padding(12)
        }
        .frame(maxHeight: 200)
    }
    
    private var createNewTagSection: some View {
        HStack(spacing: 8) {
            TextField("新建标签...", text: $newTagName)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
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
                    .font(.system(size: 18))
                    .foregroundStyle(Color.flexokiAccent)
            }
            .buttonStyle(.plain)
            .disabled(newTagName.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    private var doneButton: some View {
        Button(action: onDismiss) {
            Text("完成")
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    private func isTagSelected(_ tag: Tag) -> Bool {
        selectedTags.contains(where: { $0.id == tag.id })
    }
    
    private func toggleTag(_ tag: Tag) {
        if let index = selectedTags.firstIndex(where: { $0.id == tag.id }) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tag)
        }
        onTagsChanged()
    }
    
    private func createNewTag() {
        guard !newTagName.isEmpty else { return }
        
        do {
            let newTag = try DatabaseManager.shared.createTag(name: newTagName, color: "blue")
            selectedTags.append(newTag)
            newTagName = ""
            onTagsChanged()
        } catch {
            ClipFlowLogger.error("Failed to create tag: \(error)")
        }
    }
}

struct TagChip: View {
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
                    .font(.system(size: 11))
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
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
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

#Preview {
    VStack {
        TagSelectorView(
            allTags: [
                Tag(name: "工作", color: "blue"),
                Tag(name: "个人", color: "green"),
                Tag(name: "代码", color: "purple"),
                Tag(name: "链接", color: "orange"),
                Tag(name: "重要", color: "red")
            ],
            selectedTags: .constant([Tag(name: "工作", color: "blue")]),
            onTagsChanged: {},
            onDismiss: {}
        )
    }
    .padding()
}
