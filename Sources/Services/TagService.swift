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
        } catch {
            allTags = []
        }
    }

    func createTag(name: String, color: String) throws -> Tag {
        let tag = try db.createTag(name: name, color: color)
        refreshTags()
        return tag
    }

    func deleteTag(id: UUID) throws {
        try db.deleteTag(id: id)
        refreshTags()
    }

    func updateTag(id: UUID, name: String, color: String) throws {
        try db.updateTag(id: id, name: name, color: color)
        refreshTags()
    }

    func addTagToItem(itemId: UUID, tagId: UUID) throws {
        try db.addTagToItem(itemId: itemId, tagId: tagId)
    }

    func removeTagFromItem(itemId: UUID, tagId: UUID) throws {
        try db.removeTagFromItem(itemId: itemId, tagId: tagId)
    }

    func toggleTagOnItem(itemId: UUID, tagId: UUID) throws {
        let tags = try db.fetchTagsForItem(itemId: itemId)
        let hasTag = tags.contains { $0.id == tagId }
        if hasTag {
            try removeTagFromItem(itemId: itemId, tagId: tagId)
        } else {
            try addTagToItem(itemId: itemId, tagId: tagId)
        }
    }

    func getTagsForItem(itemId: UUID) throws -> [Tag] {
        try db.fetchTagsForItem(itemId: itemId)
    }

    func getItemsForTag(tagId: UUID) throws -> [ClipboardItem] {
        try db.fetchItemsForTag(tagId: tagId)
    }

    func searchTags(query: String) throws -> [Tag] {
        try db.searchTags(query: query)
    }
}
