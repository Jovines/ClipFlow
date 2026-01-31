import Cocoa

enum ClipboardContentDetector {
    static func hasReadableContent(from pasteboard: NSPasteboard) -> Bool {
        let types = pasteboard.types ?? []

        if types.contains(.tiff) || types.contains(.png) {
            return true
        }

        if types.contains(.string) {
            if let string = pasteboard.string(forType: .string), !string.isEmpty {
                return true
            }
        }

        return false
    }

    static func containsSensitiveData(_ content: String) -> Bool {
        let patterns = [
            "\\b(?:\\d{4}[-\\s]?){3}\\d{4}\\b",
            "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
            "(?i)(?:password|passwd|pwd|secret|token|key|api[_-]?key|auth)[\\s:]*\\S+",
            "(?:AKIA|ABIA|ACCA|ASIA)[A-Z0-9]{16}",
            "-----BEGIN\\s+(?:RSA\\s+)?PRIVATE KEY-----",
            "eyJ[A-Za-z0-9_-]*\\.eyJ[A-Za-z0-9_-]*\\.[A-Za-z0-9_-]*",
            "\\b\\d{3}[-\\s]?\\d{2}[-\\s]?\\d{4}\\b"
        ]

        for pattern in patterns {
            if content.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }

        return false
    }

    static func contentRiskLevel(_ content: String) -> RiskLevel {
        if containsSensitiveData(content) {
            return .high
        }
        return .low
    }

    enum RiskLevel {
        case low
        case medium
        case high
    }
}
