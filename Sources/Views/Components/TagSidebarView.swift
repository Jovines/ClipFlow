import SwiftUI

struct TagSidebarView: View {
    @ObservedObject var tagService: TagService
    @Binding var selectedTagIds: Set<UUID>
    let onCreateTag: () -> Void
    let onManageTags: () -> Void

    private let sidebarWidth: CGFloat = 70

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(allTags) { tag in
                        TagPillCompactView(tag: tag) {
                            toggleTag(tag.id)
                        }
                        .help(tag.name)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }

            Divider()

            HStack(spacing: 4) {
                Button(action: onCreateTag) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Create new tag")
            }
            .frame(height: 32)
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
        if selectedTagIds.contains(tagId) {
            selectedTagIds.remove(tagId)
        } else {
            selectedTagIds.insert(tagId)
        }
    }
}
