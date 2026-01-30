import Foundation

/// 标签使用统计数据结构
struct TagUsageStats: Codable, Identifiable {
    let tagId: UUID
    var useCount: Int
    var lastUsedAt: Date
    
    var id: UUID { tagId }
    
    /// 计算热度分（使用次数 × 时间衰减系数）
    /// - Parameter halfLifeDays: 半衰期天数，默认7天
    func score(halfLifeDays: Double = 7.0) -> Double {
        let daysSinceLastUse = Date().timeIntervalSince(lastUsedAt) / 86400
        let timeDecay = exp(-daysSinceLastUse / halfLifeDays)
        return Double(useCount) * timeDecay
    }
}

/// 标签使用统计管理器
final class TagUsageManager {
    static let shared = TagUsageManager()
    
    private let userDefaultsKey = "tag_usage_stats"
    private var statsCache: [UUID: TagUsageStats] = [:]
    
    private init() {
        loadStats()
    }
    
    /// 获取所有标签的使用统计
    func getAllStats() -> [TagUsageStats] {
        return Array(statsCache.values)
    }
    
    /// 获取特定标签的使用统计
    func getStats(for tagId: UUID) -> TagUsageStats {
        return statsCache[tagId] ?? TagUsageStats(tagId: tagId, useCount: 0, lastUsedAt: Date.distantPast)
    }
    
    /// 记录标签使用（筛选时调用）
    func recordUsage(for tagId: UUID) {
        var stats = statsCache[tagId] ?? TagUsageStats(tagId: tagId, useCount: 0, lastUsedAt: Date())
        stats.useCount += 1
        stats.lastUsedAt = Date()
        statsCache[tagId] = stats
        saveStats()
    }
    
    /// 获取按热度排序的标签ID列表
    func getSortedTagIds() -> [UUID] {
        let sorted = statsCache.values.sorted { $0.score() > $1.score() }
        return sorted.map { $0.tagId }
    }
    
    /// 清理未使用的标签统计（可选）
    func cleanupUnusedStats(existingTagIds: [UUID]) {
        let existingSet = Set(existingTagIds)
        statsCache = statsCache.filter { existingSet.contains($0.key) }
        saveStats()
    }
    
    // MARK: - Private
    
    private func loadStats() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([UUID: TagUsageStats].self, from: data) else {
            return
        }
        statsCache = decoded
    }
    
    private func saveStats() {
        if let data = try? JSONEncoder().encode(statsCache) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}

// MARK: - UUID 作为字典键的编码支持

extension UUID: Codable {
    // UUID 已经支持 Codable，这里只是为了明确性
}
