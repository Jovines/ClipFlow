import Foundation

enum LocalizationHelper {
    private static func bundle(for language: String) -> Bundle {
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        if let baseCode = language.split(separator: "-").first,
           let path = Bundle.main.path(forResource: String(baseCode), ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        return Bundle.main
    }

    static func localizedString(for key: String) -> String {
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        let preferredBundle = bundle(for: savedLanguage)
        let preferred = preferredBundle.localizedString(forKey: key, value: nil, table: "Localizable")
        if preferred != key {
            return preferred
        }

        let english = bundle(for: "en").localizedString(forKey: key, value: nil, table: "Localizable")
        if english != key {
            return english
        }

        return key
    }
}

extension String {
    var localized: String {
        LocalizationHelper.localizedString(for: self)
    }

    func localized(_ args: CVarArg...) -> String {
        let format = LocalizationHelper.localizedString(for: self)
        if args.isEmpty {
            return format
        } else {
            return String(format: format, args)
        }
    }

    func localized(comment: String) -> String {
        LocalizationHelper.localizedString(for: self)
    }
}

extension String.LocalizationValue {
    init(_ key: String) {
        self = String.LocalizationValue(key)
    }
}
