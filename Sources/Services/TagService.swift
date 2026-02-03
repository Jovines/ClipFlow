import Foundation
import Combine

@MainActor
final class TagService: ObservableObject {
    static let shared = TagService()

    @Published private(set) var allTags: [Tag] = []

    private let db = DatabaseManager.shared

    private init() {
        refreshTags()
    }

    func refreshTags() {
        do {
            allTags = try db.fetchAllTags()
            print("[TagService] refreshTags: loaded \(allTags.count) tags")
            for tag in allTags {
                print("  - \(tag.name) (id: \(tag.id.uuidString.prefix(8)))")
            }
        } catch {
            print("[TagService] Failed to fetch tags: \(error)")
            allTags = []
        }
    }

    func createTag(name: String, color: String) throws -> Tag {
        print("[TagService] createTag: name=\(name), color=\(color)")
        let tag = try db.createTag(name: name, color: color)
        refreshTags()
        print("[TagService] createTag: created tag id=\(tag.id.uuidString)")
        return tag
    }

    func deleteTag(id: UUID) throws {
        print("[TagService] deleteTag: id=\(id.uuidString)")
        try db.deleteTag(id: id)
        refreshTags()
    }

    func updateTag(id: UUID, name: String, color: String) throws {
        print("[TagService] updateTag: id=\(id.uuidString), name=\(name), color=\(color)")
        try db.updateTag(id: id, name: name, color: color)
        refreshTags()
    }

    func addTagToItem(itemId: UUID, tagId: UUID) throws {
        print("[TagService] addTagToItem: itemId=\(itemId.uuidString), tagId=\(tagId.uuidString)")
        try db.addTagToItem(itemId: itemId, tagId: tagId)
    }

    func removeTagFromItem(itemId: UUID, tagId: UUID) throws {
        print("[TagService] removeTagFromItem: itemId=\(itemId.uuidString), tagId=\(tagId.uuidString)")
        try db.removeTagFromItem(itemId: itemId, tagId: tagId)
    }

    func toggleTagOnItem(itemId: UUID, tagId: UUID) throws {
        let tags = try db.fetchTagsForItem(itemId: itemId)
        let hasTag = tags.contains { $0.id == tagId }
        print("[TagService] toggleTagOnItem: itemId=\(itemId.uuidString), tagId=\(tagId.uuidString), hasTag=\(hasTag)")
        if hasTag {
            try removeTagFromItem(itemId: itemId, tagId: tagId)
        } else {
            try addTagToItem(itemId: itemId, tagId: tagId)
        }
    }

    func getTagsForItem(itemId: UUID) throws -> [Tag] {
        let tags = try db.fetchTagsForItem(itemId: itemId)
        print("[TagService] getTagsForItem: itemId=\(itemId.uuidString), tagsCount=\(tags.count)")
        for tag in tags {
            print("  - \(tag.name) (id: \(tag.id.uuidString.prefix(8)))")
        }
        return tags
    }

    func getItemsForTag(tagId: UUID) throws -> [ClipboardItem] {
        let items = try db.fetchItemsForTag(tagId: tagId)
        print("[TagService] getItemsForTag: tagId=\(tagId.uuidString), itemsCount=\(items.count)")
        return items
    }

    func searchTags(query: String) throws -> [Tag] {
        print("[TagService] searchTags: query=\(query)")
        return try db.searchTags(query: query)
    }
}
