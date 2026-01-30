import CoreData
import Foundation

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "ClipFlow")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Failed to load Core Data stack: \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Configure for heavy operations
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true
    }

    func saveContext() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Error saving context: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    // MARK: - Background Operations

    /// Perform a background Core Data operation
    /// - Parameter block: The operation to perform on a background context
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask(block)
    }

    /// Create a new background context for manual use
    /// - Returns: A new background context configured for saving
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.undoManager = nil
        return context
    }

    // MARK: - Clipboard Items

    @discardableResult
    func createClipboardItem(
        content: String,
        contentType: String,
        imageData: Data? = nil,
        thumbnailData: Data? = nil,
        imagePath: String? = nil,
        thumbnailPath: String? = nil,
        contentHash: Int = 0,
        tagNames: [String] = []
    ) -> NSManagedObject {
        let item = NSEntityDescription.insertNewObject(
            forEntityName: "ClipboardItemEntity",
            into: viewContext
        )

        item.setValue(UUID(), forKey: "id")
        item.setValue(content, forKey: "content")
        item.setValue(contentType, forKey: "contentType")
        item.setValue(imageData, forKey: "imageData")
        item.setValue(thumbnailData, forKey: "thumbnailData")
        item.setValue(imagePath, forKey: "imagePath")
        item.setValue(thumbnailPath, forKey: "thumbnailPath")
        item.setValue(Date(), forKey: "createdAt")
        item.setValue(Date(), forKey: "updatedAt")
        item.setValue(contentHash, forKey: "contentHash")

        if !tagNames.isEmpty {
            var tags: [NSManagedObject] = []
            for tagName in tagNames {
                if let tag = fetchTag(byName: tagName) {
                    tags.append(tag)
                } else {
                    tags.append(createTag(name: tagName, color: Tag.colorForName("blue")))
                }
            }
            item.setValue(NSSet(array: tags), forKey: "tags")
        }

        saveContext()
        return item
    }

    func fetchClipboardItems(
        limit: Int = 100,
        offset: Int = 0,
        searchText: String? = nil,
        tagFilter: String? = nil
    ) -> [NSManagedObject] {
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "ClipboardItemEntity")

        var predicates: [NSPredicate] = []

        if let searchText = searchText, !searchText.isEmpty {
            predicates.append(NSPredicate(format: "content CONTAINS[cd] %@", searchText))
        }

        if let tagFilter = tagFilter {
            predicates.append(NSPredicate(format: "ANY tags.name == %@", tagFilter))
        }

        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = limit
        request.fetchOffset = offset

        do {
            return try viewContext.fetch(request) as? [NSManagedObject] ?? []
        } catch {
            print("Error fetching clipboard items: \(error)")
            return []
        }
    }

    func fetchClipboardItem(by id: UUID) -> NSManagedObject? {
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "ClipboardItemEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            return try viewContext.fetch(request).first as? NSManagedObject
        } catch {
            print("Error fetching clipboard item by id: \(error)")
            return nil
        }
    }

    func updateClipboardItem(_ item: NSManagedObject, content: String? = nil, imagePath: String? = nil, thumbnailPath: String? = nil) {
        if let content = content {
            item.setValue(content, forKey: "content")
        }
        if let imagePath = imagePath {
            item.setValue(imagePath, forKey: "imagePath")
        }
        if let thumbnailPath = thumbnailPath {
            item.setValue(thumbnailPath, forKey: "thumbnailPath")
        }
        item.setValue(Date(), forKey: "updatedAt")
        saveContext()
    }

    func deleteClipboardItem(_ item: NSManagedObject) {
        viewContext.delete(item)
        saveContext()
    }

    func deleteAllClipboardItems() {
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "ClipboardItemEntity")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

        do {
            try container.persistentStoreCoordinator.execute(deleteRequest, with: viewContext)
            viewContext.reset()
        } catch {
            print("Error deleting all items: \(error)")
        }
    }

    func cleanupExcessItems(keepCount: Int) {
        let items = fetchClipboardItems(limit: keepCount + 100)
        if items.count > keepCount {
            let itemsToDelete = Array(items.suffix(from: keepCount))
            for item in itemsToDelete {
                viewContext.delete(item)
            }
            saveContext()
        }
    }

    // MARK: - Deduplication

    func existsItem(withHash hash: Int) -> Bool {
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "ClipboardItemEntity")
        request.predicate = NSPredicate(format: "contentHash == %d", hash)
        request.fetchLimit = 1

        do {
            let count = try viewContext.count(for: request)
            return count > 0
        } catch {
            print("Error checking for duplicate: \(error)")
            return false
        }
    }

    // MARK: - Tags

    @discardableResult
    func createTag(name: String, color: String) -> NSManagedObject {
        let tag = NSEntityDescription.insertNewObject(
            forEntityName: "TagEntity",
            into: viewContext
        )

        tag.setValue(UUID(), forKey: "id")
        tag.setValue(name, forKey: "name")
        tag.setValue(color, forKey: "color")
        tag.setValue(Date(), forKey: "createdAt")

        saveContext()
        return tag
    }

    func fetchAllTags() -> [NSManagedObject] {
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "TagEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        do {
            return try viewContext.fetch(request) as? [NSManagedObject] ?? []
        } catch {
            print("Error fetching tags: \(error)")
            return []
        }
    }

    func fetchTag(byName name: String) -> NSManagedObject? {
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "TagEntity")
        request.predicate = NSPredicate(format: "name == %@", name)
        request.fetchLimit = 1

        do {
            return try viewContext.fetch(request).first as? NSManagedObject
        } catch {
            print("Error fetching tag by name: \(error)")
            return nil
        }
    }

    func fetchTag(byId id: UUID) -> NSManagedObject? {
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "TagEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            return try viewContext.fetch(request).first as? NSManagedObject
        } catch {
            print("Error fetching tag by id: \(error)")
            return nil
        }
    }

    func deleteTag(_ tag: NSManagedObject) {
        viewContext.delete(tag)
        saveContext()
    }

    func updateTagColor(_ tag: NSManagedObject, color: String) {
        tag.setValue(color, forKey: "color")
        saveContext()
    }

    func updateTagName(_ tag: NSManagedObject, name: String) {
        tag.setValue(name, forKey: "name")
        saveContext()
    }
}
