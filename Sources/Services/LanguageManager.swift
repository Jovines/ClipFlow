import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case en = "en"
    case zhHans = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .en: return "English".localized()
        case .zhHans: return "Simplified Chinese".localized()
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
        let appleLanguages = UserDefaults.standard.array(forKey: "AppleLanguages")
        print("[LanguageManager] init - savedValue: \(savedValue), AppleLanguages: \(appleLanguages?.description ?? "nil")")
        if let language = AppLanguage(rawValue: savedValue), AppLanguage.allCases.contains(language) {
            self.currentLanguage = language
            print("[LanguageManager] init - loaded language: \(language.rawValue)")
        } else {
            self.currentLanguage = .en
            print("[LanguageManager] init - fallback to English")
        }
    }

    func setLanguage(_ language: AppLanguage) {
        print("[LanguageManager] setLanguage called: \(language.rawValue)")
        currentLanguage = language
        refreshTrigger += 1
        UserDefaults.standard.set(language.rawValue, forKey: userDefaultsKey)
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        print("[LanguageManager] setLanguage - UserDefaults appLanguage: \(language.rawValue)")
        print("[LanguageManager] setLanguage - UserDefaults AppleLanguages: \(UserDefaults.standard.array(forKey: "AppleLanguages")?.description ?? "nil")")
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
