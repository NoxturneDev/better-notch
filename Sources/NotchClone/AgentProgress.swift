import Foundation

struct AgentProgress: Equatable, Sendable {
    let text: String
    let date: Date?
    let isRecap: Bool

    var relativeAge: String? {
        guard let date else { return nil }
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 0 { return "just now" }
        let minutes = Int(elapsed / 60)
        if minutes < 1 { return "just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = Int(elapsed / 3600)
        if hours < 24 { return "\(hours)h ago" }
        let calendar = Calendar.current
        if calendar.isDateInYesterday(date) { return "yesterday" }
        let days = Int(elapsed / 86400)
        if days < 7 { return "\(days)d ago" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
