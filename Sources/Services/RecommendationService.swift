import Foundation
import GRDB

final class RecommendationService: ObservableObject, @unchecked Sendable {
    static let shared = RecommendationService()

    private let dbManager = DatabaseManager.shared
    private let maxRecommendations = 5
    private let minRecommendationScore = Double.leastNonzeroMagnitude

    private init() {}

    func updateUsage(itemId: UUID) throws {
        try dbManager.dbPool.write { db in
            try db.execute(sql: """
                UPDATE clipboard_items
                SET usageCount = usageCount + 1,
                    lastUsedAt = ?,
                    recommendationScore = ?,
                    recommendedAt = COALESCE(recommendedAt, ?)
                WHERE id = ?
                """, arguments: [
                    Date(),
                    ClipboardItem.calculateScore(usageCount: 1, daysSinceLastUse: 0),
                    Date(),
                    itemId.uuidString
                ])
        }
    }

    func recalculateRecommendations() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                let allItems = try dbManager.fetchClipboardItems(limit: 1000)
                var scoredItems: [(item: ClipboardItem, score: Double)] = []

                for item in allItems {
                    let score = ClipboardItem.calculateScore(
                        usageCount: item.usageCount,
                        daysSinceLastUse: item.daysSinceLastUse
                    )
                    scoredItems.append((item, score))
                }

                scoredItems.sort { $0.score > $1.score }

                let currentRecommended = scoredItems.filter { $0.item.isCurrentlyRecommended }
                let currentIds = Set(currentRecommended.map { $0.item.id })

                let toEvict = currentRecommended.filter { itemWithScore in
                    !itemWithScore.item.shouldBeRecommended
                }

                let candidates = scoredItems.filter { !currentIds.contains($0.item.id) && $0.item.shouldBeRecommended }

                try dbManager.dbPool.write { db in
                    for evicted in toEvict {
                        try db.execute(sql: """
                            UPDATE clipboard_items
                            SET evictedAt = ?, recommendedAt = NULL
                            WHERE id = ?
                            """, arguments: [Date(), evicted.item.id.uuidString])
                    }

                    let slotsAvailable = max(0, maxRecommendations - (currentRecommended.count - toEvict.count))

                    for candidate in candidates.prefix(slotsAvailable) {
                        try db.execute(sql: """
                            UPDATE clipboard_items
                            SET recommendedAt = ?, evictedAt = NULL, recommendationScore = ?
                            WHERE id = ?
                            """, arguments: [Date(), candidate.score, candidate.item.id.uuidString])
                    }
                }

                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func fetchRecommendedItems() throws -> [ClipboardItem] {
        try dbManager.dbPool.read { db in
            let sql = """
                SELECT * FROM clipboard_items
                WHERE recommendedAt IS NOT NULL AND evictedAt IS NULL
                ORDER BY recommendationScore DESC
                LIMIT ?
                """
            return try ClipboardItem.fetchAll(db, sql: sql, arguments: [maxRecommendations])
        }
    }

    func fetchRecommendationHistory() throws -> [ClipboardItem] {
        try dbManager.dbPool.read { db in
            let sql = """
                SELECT * FROM clipboard_items
                WHERE recommendedAt IS NOT NULL
                ORDER BY
                    CASE WHEN evictedAt IS NOT NULL THEN 1 ELSE 0 END,
                    COALESCE(evictedAt, recommendedAt) DESC
                LIMIT 50
                """
            return try ClipboardItem.fetchAll(db, sql: sql)
        }
    }

    func markAsRecommended(itemId: UUID) throws {
        try dbManager.dbPool.write { db in
            try db.execute(sql: """
                UPDATE clipboard_items
                SET recommendedAt = ?, evictedAt = NULL
                WHERE id = ?
                """, arguments: [Date(), itemId.uuidString])
        }
    }

    func evictFromRecommendations(itemId: UUID) throws {
        try dbManager.dbPool.write { db in
            try db.execute(sql: """
                UPDATE clipboard_items
                SET evictedAt = ?, recommendedAt = NULL
                WHERE id = ?
                """, arguments: [Date(), itemId.uuidString])
        }
    }

    func clearRecommendationHistory() throws {
        try dbManager.dbPool.write { db in
            try db.execute(sql: """
                UPDATE clipboard_items SET evictedAt = NULL
                WHERE evictedAt IS NOT NULL AND recommendedAt IS NULL
                """)
        }
    }
}
