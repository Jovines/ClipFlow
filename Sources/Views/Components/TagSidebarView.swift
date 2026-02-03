import SwiftUI

struct TagSidebarView: View {
    @ObservedObject var tagService: TagService
    @Binding var selectedTagIds: [UUID]
    let onCreateTag: () -> Void
    let onManageTags: () -> Void

    private let sidebarWidth: CGFloat = 80

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(allTags) { tag in
                        TagSidebarRowView(
                            tag: tag,
                            isSelected: selectedTagIds.contains(tag.id),
                            onTap: { toggleTag(tag.id) }
                        )
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
            }

            Divider()

            HStack(spacing: 4) {
                Button(action: onCreateTag) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Create new tag")
            }
            .frame(height: 28)
            .background(Color.flexokiSurface)
        }
        .frame(width: sidebarWidth)
        .background(Color.flexokiSurface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
}

struct TagSidebarRowView: View {
    let tag: Tag
    let isSelected: Bool
    let onTap: () -> Void

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
            .background(isSelected ? Color.hex(tag.color).opacity(0.15) : Color.clear)
            .foregroundStyle(isSelected ? Color.hex(tag.color) : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
