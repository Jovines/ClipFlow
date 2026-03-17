import Foundation

struct FocusTodoItem: Identifiable, Codable, Equatable {
    enum State: String, Codable {
        case pending
        case paused
        case done
    }

    let id: UUID
    var title: String
    var state: State
    let createdAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        state: State = .pending,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.state = state
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}
