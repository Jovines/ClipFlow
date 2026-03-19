import SwiftUI

@main
struct ClipFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var languageManager = LanguageManager.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView()
                .environment(\.locale, languageManager.currentLanguage.locale)
                .environment(\.currentLocale, languageManager.currentLanguage.locale)
        } label: {
            Image(systemName: "doc.on.clipboard")
        }
        .menuBarExtraStyle(.window)
    }
}
