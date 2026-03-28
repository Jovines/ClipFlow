import Foundation

enum FocusTodoPreferences {
    static let isEnabledKey = "focusTodoEnabled"
    static let itemsKey = "focusTodo.items"
    static let activeItemIdKey = "focusTodo.activeItemId"
    static let shortcutsKey = "focusTodo.shortcuts"
    static let snapPositionKey = "focusTodoSnapPosition"
    static let clipboardPrefillSecondsKey = "focusTodoClipboardPrefillSeconds"
    static let collapsedOpacityKey = "focusTodoCollapsedOpacity"
    static let rewriteAutoFromClipboardKey = "focusTodoRewriteAutoFromClipboard"
    static let rewriteProviderIdKey = "focusTodoRewriteProviderId"
    static let defaultIsEnabled = false

    static let defaultClipboardPrefillSeconds = 20.0
    static let defaultCollapsedOpacity = 0.36
    static let defaultRewriteAutoFromClipboard = false
    static let defaultRewriteProviderId = ""
}
