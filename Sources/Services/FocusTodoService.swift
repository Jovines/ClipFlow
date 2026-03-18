import CoreGraphics
import Foundation

@MainActor
final class FocusTodoService: ObservableObject {
    static let shared = FocusTodoService()

    @Published private(set) var items: [FocusTodoItem] = []
    @Published private(set) var activeItemId: UUID?
    @Published var isPanelExpanded = false
    @Published private(set) var activeSwitchSerial = 0
    @Published private(set) var collapsedInteractionSerial = 0
    @Published private(set) var isCollapsedDragging = false
    @Published private(set) var measuredCollapsedHeight: CGFloat = 42
    @Published private(set) var measuredExpandedHeight: CGFloat = 286

    private let itemsKey = FocusTodoPreferences.itemsKey
    private let activeIdKey = FocusTodoPreferences.activeItemIdKey

    var activeItem: FocusTodoItem? {
        guard let activeItemId else { return nil }
        return items.first(where: { $0.id == activeItemId && $0.state != .done })
    }

    var queuedItems: [FocusTodoItem] {
        items.filter { $0.state == .pending && $0.id != activeItemId }
    }

    var pausedItems: [FocusTodoItem] {
        items.filter { $0.state == .paused }
    }

    var doneTodayItems: [FocusTodoItem] {
        let calendar = Calendar.current
        return items.filter { item in
            guard item.state == .done, let completedAt = item.completedAt else { return false }
            return calendar.isDateInToday(completedAt)
        }
    }

    private init() {
        load()
        normalizeActiveItemIfNeeded()
    }

    func togglePanel() {
        isPanelExpanded.toggle()
    }

    func setPanelExpanded(_ expanded: Bool) {
        isPanelExpanded = expanded
    }

    func addTask(_ title: String, makeActive: Bool = false) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let item = FocusTodoItem(title: trimmed)
        items.append(item)

        if activeItemId == nil || makeActive {
            activeItemId = item.id
        }

        save()
    }

    func setActive(_ itemId: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        guard items[index].state != .done else { return }

        if items[index].state == .paused {
            items[index].state = .pending
        }
        activeItemId = itemId
        save()
    }

    func markCurrentDone() {
        guard let activeItemId,
              let index = items.firstIndex(where: { $0.id == activeItemId }) else {
            return
        }

        items[index].state = .done
        items[index].completedAt = Date()

        self.activeItemId = nil
        pickFirstPendingAsActive()
        save()
    }

    func moveToNext() {
        let pendingIds = items.filter { $0.state == .pending }.map(\.id)
        guard !pendingIds.isEmpty else { return }

        let previousActiveId = activeItemId

        guard let activeItemId,
              let currentIndex = pendingIds.firstIndex(of: activeItemId) else {
            self.activeItemId = pendingIds[0]
            if previousActiveId != self.activeItemId {
                bumpActiveSwitchAnimation()
            }
            save()
            return
        }

        let nextIndex = (currentIndex + 1) % pendingIds.count
        self.activeItemId = pendingIds[nextIndex]
        if previousActiveId != self.activeItemId {
            bumpActiveSwitchAnimation()
        }
        save()
    }

    func moveToPrevious() {
        let pendingIds = items.filter { $0.state == .pending }.map(\.id)
        guard !pendingIds.isEmpty else { return }

        let previousActiveId = activeItemId

        guard let activeItemId,
              let currentIndex = pendingIds.firstIndex(of: activeItemId) else {
            self.activeItemId = pendingIds[0]
            if previousActiveId != self.activeItemId {
                bumpActiveSwitchAnimation()
            }
            save()
            return
        }

        let previousIndex = (currentIndex - 1 + pendingIds.count) % pendingIds.count
        self.activeItemId = pendingIds[previousIndex]
        if previousActiveId != self.activeItemId {
            bumpActiveSwitchAnimation()
        }
        save()
    }

    private func bumpActiveSwitchAnimation() {
        activeSwitchSerial += 1
    }

    func notifyCollapsedInteraction() {
        guard !isPanelExpanded else { return }
        collapsedInteractionSerial += 1
    }

    func setCollapsedDragging(_ dragging: Bool) {
        guard isCollapsedDragging != dragging else { return }
        isCollapsedDragging = dragging
    }

    func updateMeasuredHeight(_ height: CGFloat, expanded: Bool) {
        let normalized = max(30, ceil(height) + 1)
        if expanded {
            guard abs(measuredExpandedHeight - normalized) > 0.5 else { return }
            measuredExpandedHeight = normalized
        } else {
            guard abs(measuredCollapsedHeight - normalized) > 0.5 else { return }
            measuredCollapsedHeight = normalized
        }
    }

    func pauseCurrent() {
        guard let activeItemId,
              let index = items.firstIndex(where: { $0.id == activeItemId }) else {
            return
        }

        items[index].state = .paused
        self.activeItemId = nil
        pickFirstPendingAsActive()
        save()
    }

    func resumePaused(_ itemId: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        items[index].state = .pending
        activeItemId = itemId
        save()
    }

    func delete(_ itemId: UUID) {
        items.removeAll { $0.id == itemId }
        if activeItemId == itemId {
            activeItemId = nil
            pickFirstPendingAsActive()
        }
        save()
    }

    func restoreDone(_ itemId: UUID, makeActive: Bool = false) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        guard items[index].state == .done else { return }

        items[index].state = .pending
        items[index].completedAt = nil

        if makeActive || activeItemId == nil {
            activeItemId = itemId
        }

        save()
    }

    private func pickFirstPendingAsActive() {
        if let firstPending = items.first(where: { $0.state == .pending }) {
            activeItemId = firstPending.id
        }
    }

    private func normalizeActiveItemIfNeeded() {
        if let activeItemId,
           let item = items.first(where: { $0.id == activeItemId }),
           item.state != .done {
            return
        }

        self.activeItemId = nil
        pickFirstPendingAsActive()
        save()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: itemsKey),
           let decoded = try? JSONDecoder().decode([FocusTodoItem].self, from: data) {
            items = decoded
        }

        if let activeIdString = UserDefaults.standard.string(forKey: activeIdKey) {
            activeItemId = UUID(uuidString: activeIdString)
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: itemsKey)
        }

        UserDefaults.standard.set(activeItemId?.uuidString, forKey: activeIdKey)
    }
}
