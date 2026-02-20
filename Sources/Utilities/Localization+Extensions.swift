import Foundation

enum LocalizationHelper {
    private static func loadStrings() -> [String: [String: String]] {
        guard let url = Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: [String: Any]] else {
            return [:]
        }

        var result: [String: [String: String]] = [:]
        for (key, value) in strings {
            if let localization = value["localizations"] as? [String: [String: Any]] {
                var translations: [String: String] = [:]
                for (lang, langValue) in localization {
                    if let stringUnit = langValue["stringUnit"] as? [String: Any],
                       let translatedValue = stringUnit["value"] as? String {
                        translations[lang] = translatedValue
                    }
                }
                result[key] = translations
            }
        }

        return result
    }

    static func localizedString(for key: String) -> String {
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        let strings = loadStrings()

        if let translations = strings[key],
           let translation = translations[savedLanguage] {
            return translation
        }

        if let translations = strings[key],
           let translation = translations["en"] {
            return translation
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
