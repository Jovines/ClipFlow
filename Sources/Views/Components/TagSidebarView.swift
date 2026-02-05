import SwiftUI

struct TagSidebarView: View {
    @ObservedObject var tagService: TagService
    @Binding var selectedTagIds: [UUID]
    let onManageTags: () -> Void
    @Binding var showRecommendationHistory: Bool

    private let sidebarWidth: CGFloat = 80

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text("筛选")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
            }
            .frame(height: 36)
            .padding(.horizontal, 8)

            Divider()

            ScrollView {
                VStack(spacing: 4) {
                    RecommendationHistorySidebarItem(
                        isSelected: $showRecommendationHistory,
                        count: tagService.recommendationHistoryCount
                    )
                    .onTapGesture {
                        showRecommendationHistory.toggle()
                    }

                    Divider()
                        .padding(.vertical, 4)

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
                Button(action: onManageTags) {
                    Image(systemName: "tag")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Manage tags")
            }
            .frame(height: 28)
            .padding(.horizontal, 6)
            .background(ThemeManager.shared.surface)
        }
        .frame(width: sidebarWidth)
        .background(ThemeManager.shared.surface.opacity(0.5))
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

struct RecommendationHistorySidebarItem: View {
    @Binding var isSelected: Bool
    let count: Int

    var body: some View {
        Button {
            isSelected.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? Color.flexokiYellow : .secondary)

                Text("推荐历史")
                    .font(.system(size: 10))
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.flexokiYellow.opacity(0.15) : Color.clear)
            .foregroundStyle(isSelected ? Color.flexokiYellow : .secondary)
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
