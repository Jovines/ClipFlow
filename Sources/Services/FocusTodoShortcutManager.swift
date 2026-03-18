import Foundation

@MainActor
final class FocusTodoShortcutManager: ObservableObject {
    enum Action: String, CaseIterable {
        case togglePanel
        case previousTask
        case nextTask
        case markDone

        var defaultShortcut: HotKeyManager.Shortcut {
            switch self {
            case .togglePanel:
                return HotKeyManager.Shortcut(keyCode: kVK_ANSI_T, modifiers: [.control, .option])
            case .previousTask:
                return HotKeyManager.Shortcut(keyCode: kVK_ANSI_P, modifiers: [.control, .option])
            case .nextTask:
                return HotKeyManager.Shortcut(keyCode: kVK_ANSI_N, modifiers: [.control, .option])
            case .markDone:
                return HotKeyManager.Shortcut(keyCode: kVK_ANSI_D, modifiers: [.control, .option])
            }
        }
    }

    struct Configuration: Codable {
        var togglePanel: HotKeyManager.Shortcut
        var previousTask: HotKeyManager.Shortcut
        var nextTask: HotKeyManager.Shortcut
        var markDone: HotKeyManager.Shortcut

        enum CodingKeys: String, CodingKey {
            case togglePanel
            case previousTask
            case nextTask
            case markDone
        }

        init(
            togglePanel: HotKeyManager.Shortcut,
            previousTask: HotKeyManager.Shortcut,
            nextTask: HotKeyManager.Shortcut,
            markDone: HotKeyManager.Shortcut
        ) {
            self.togglePanel = togglePanel
            self.previousTask = previousTask
            self.nextTask = nextTask
            self.markDone = markDone
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            togglePanel = try container.decode(HotKeyManager.Shortcut.self, forKey: .togglePanel)
            previousTask = try container.decodeIfPresent(HotKeyManager.Shortcut.self, forKey: .previousTask) ?? Action.previousTask.defaultShortcut
            nextTask = try container.decode(HotKeyManager.Shortcut.self, forKey: .nextTask)
            markDone = try container.decode(HotKeyManager.Shortcut.self, forKey: .markDone)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(togglePanel, forKey: .togglePanel)
            try container.encode(previousTask, forKey: .previousTask)
            try container.encode(nextTask, forKey: .nextTask)
            try container.encode(markDone, forKey: .markDone)
        }

        static var `default`: Configuration {
            Configuration(
                togglePanel: Action.togglePanel.defaultShortcut,
                previousTask: Action.previousTask.defaultShortcut,
                nextTask: Action.nextTask.defaultShortcut,
                markDone: Action.markDone.defaultShortcut
            )
        }
    }

    static let shared = FocusTodoShortcutManager()

    @Published private(set) var configuration: Configuration

    private let userDefaultsKey = FocusTodoPreferences.shortcutsKey

    private init() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(Configuration.self, from: data) {
            configuration = decoded
        } else {
            configuration = .default
        }
    }

    func shortcut(for action: Action) -> HotKeyManager.Shortcut {
        switch action {
        case .togglePanel:
            return configuration.togglePanel
        case .previousTask:
            return configuration.previousTask
        case .nextTask:
            return configuration.nextTask
        case .markDone:
            return configuration.markDone
        }
    }

    func update(shortcut: HotKeyManager.Shortcut, for action: Action) {
        switch action {
        case .togglePanel:
            configuration.togglePanel = shortcut
        case .previousTask:
            configuration.previousTask = shortcut
        case .nextTask:
            configuration.nextTask = shortcut
        case .markDone:
            configuration.markDone = shortcut
        }
        save()
    }

    func hasDuplicate(with candidate: HotKeyManager.Shortcut, excluding action: Action) -> Bool {
        Action.allCases
            .filter { $0 != action }
            .contains { shortcut(for: $0) == candidate }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
