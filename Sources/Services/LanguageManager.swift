import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case en = "en"
    case zhHans = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .en: return "English"
        case .zhHans: return "简体中文"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

@MainActor
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published private(set) var currentLanguage: AppLanguage
    @Published var refreshTrigger: Int = 0

    private let userDefaultsKey = "appLanguage"

    private init() {
        let savedValue = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        if let language = AppLanguage(rawValue: savedValue), AppLanguage.allCases.contains(language) {
            self.currentLanguage = language
        } else {
            self.currentLanguage = .en
        }
    }

    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
        refreshTrigger += 1
        UserDefaults.standard.set(language.rawValue, forKey: userDefaultsKey)
    }
}

struct LanguageRefreshModifier: ViewModifier {
    @ObservedObject var languageManager: LanguageManager

    func body(content: Content) -> some View {
        content
            .id(languageManager.refreshTrigger)
    }
}

extension View {
    func refreshOnLanguageChange() -> some View {
        modifier(LanguageRefreshModifier(languageManager: LanguageManager.shared))
    }
}

struct LocaleKey: EnvironmentKey {
    static let defaultValue: Locale = Locale.current
}

extension EnvironmentValues {
    var currentLocale: Locale {
        get { self[LocaleKey.self] }
        set { self[LocaleKey.self] = newValue }
    }
}
