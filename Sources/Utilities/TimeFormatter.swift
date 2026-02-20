import Foundation

enum TimeFormatter {
    static func relativeTime(from date: Date) -> String {
        let now = Date()
        let elapsed = now.timeIntervalSince(date)

        if elapsed < 60 {
            return "Just Now".localized()
        } else if elapsed < 120 {
            return "1 Minute Ago".localized()
        } else if elapsed < 180 {
            return "2 Minutes Ago".localized()
        } else if elapsed < 240 {
            return "3 Minutes Ago".localized()
        } else if elapsed < 300 {
            return "4 Minutes Ago".localized()
        } else if elapsed < 600 {
            return "5 Minutes Ago".localized()
        } else if elapsed < 900 {
            return "10 Minutes Ago".localized()
        } else if elapsed < 1200 {
            return "15 Minutes Ago".localized()
        } else if elapsed < 1800 {
            return "20 Minutes Ago".localized()
        } else if elapsed < 3600 {
            return "Half Hour Ago".localized()
        } else if elapsed < 7200 {
            return "1 Hour Ago".localized()
        } else if elapsed < 86400 {
            let hours = Int(elapsed / 3600)
            return "%1$d Hours Ago".localized(hours)
        } else {
            let days = Int(elapsed / 86400)
            if days == 1 {
                return "1 Day Ago".localized()
            } else {
                return "%1$d Days Ago".localized(days)
            }
        }
    }

    static func relativeTime(fromISOString isoString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: isoString) else {
            return ""
        }
        return relativeTime(from: date)
    }
}
