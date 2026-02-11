import Foundation

enum TimeFormatter {
    static func relativeTime(from date: Date) -> String {
        let now = Date()
        let elapsed = now.timeIntervalSince(date)

        if elapsed < 60 {
            return "Just Now".localized
        } else if elapsed < 120 {
            return String(format: "Minutes Ago".localized, 1)
        } else if elapsed < 180 {
            return String(format: "Minutes Ago".localized, 2)
        } else if elapsed < 240 {
            return String(format: "Minutes Ago".localized, 3)
        } else if elapsed < 300 {
            return String(format: "Minutes Ago".localized, 4)
        } else if elapsed < 600 {
            return String(format: "Minutes Ago".localized, 5)
        } else if elapsed < 900 {
            return String(format: "Minutes Ago".localized, 10)
        } else if elapsed < 1200 {
            return String(format: "Minutes Ago".localized, 15)
        } else if elapsed < 1800 {
            return String(format: "Minutes Ago".localized, 20)
        } else if elapsed < 3600 {
            return "Half Hour Ago".localized
        } else if elapsed < 7200 {
            return String(format: "Hours Ago".localized, 1)
        } else if elapsed < 86400 {
            let hours = Int(elapsed / 3600)
            return String(format: "Hours Ago".localized, hours)
        } else {
            let days = Int(elapsed / 86400)
            return String(format: "Days Ago".localized, days)
        }
    }

    static func relativeTime(fromISOString isoString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: isoString) else {
            return ""
        }
        return relativeTime(from: date)
    }
}
