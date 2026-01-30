import SwiftUI

struct TagFilterBar: View {
    let tags: [Tag]
    @Binding var selectedTag: Tag?
    let onTagSelected: (Tag?) -> Void
    
    @State private var sortedTags: [Tag] = []
    
    var body: some View {
        if !sortedTags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(sortedTags) { tag in
                        FilterChip(
                            name: tag.name,
                            color: tag.color,
                            isSelected: selectedTag?.id == tag.id
                        ) {
                            onTagSelected(tag)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .frame(height: 32)
            .background(Color.flexokiSurface.opacity(0.3))
            .onAppear {
                updateSortedTags()
            }
            .onChange(of: tags) { _, _ in
                updateSortedTags()
            }
        }
    }
    
    private func updateSortedTags() {
        let sortedIds = TagUsageManager.shared.getSortedTagIds()
        let tagMap = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0) })
        
        sortedTags = sortedIds.compactMap { tagMap[$0] }
        
        let remainingTags = tags.filter { tag in
            !sortedIds.contains(tag.id)
        }
        sortedTags.append(contentsOf: remainingTags)
    }
}

struct FilterChip: View {
    let name: String
    let color: String?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let color = color {
                    Circle()
                        .fill(Color.flexokiTagColor(for: color))
                        .frame(width: 6, height: 6)
                }
                Text(name)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
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
            if let color = color {
                return Color.flexokiTagColor(for: color).opacity(0.3)
            }
            return Color.flexokiAccent.opacity(0.3)
        }
        return Color.flexokiSurface.opacity(0.5)
    }
    
    private var foregroundColor: Color {
        if isSelected {
            if let color = color {
                return Color.flexokiTagColor(for: color)
            }
            return Color.flexokiAccent
        }
        return Color.flexokiText
    }
}

#Preview {
    VStack(spacing: 20) {
        TagFilterBar(
            tags: [
                Tag(name: "Work", color: "blue"),
                Tag(name: "个人", color: "green"),
                Tag(name: "代码", color: "purple"),
                Tag(name: "链接", color: "orange")
            ],
            selectedTag: .constant(nil),
            onTagSelected: { _ in }
        )
        .frame(width: 360)
        
        TagFilterBar(
            tags: [
                Tag(name: "Work", color: "blue"),
                Tag(name: "个人", color: "green"),
                Tag(name: "代码", color: "purple"),
                Tag(name: "链接", color: "orange")
            ],
            selectedTag: .constant(Tag(name: "Work", color: "blue")),
            onTagSelected: { _ in }
        )
        .frame(width: 360)
    }
    .padding()
}
