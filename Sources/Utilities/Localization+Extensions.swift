import Foundation

extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    func localized(_ args: CVarArg...) -> String {
        if args.isEmpty {
            return NSLocalizedString(self, comment: "")
        } else {
            return String(format: NSLocalizedString(self, comment: ""), arguments: args)
        }
    }

    func localized(comment: String) -> String {
        NSLocalizedString(self, comment: comment)
    }
}

extension String.LocalizationValue {
    init(_ key: String) {
        self = String.LocalizationValue(key)
    }
}
