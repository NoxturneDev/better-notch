import Foundation

struct TodayItem: Identifiable, Equatable, Sendable, Hashable {
    enum State: String, CaseIterable, Equatable, Sendable, Hashable {
        case readyToWrapUp = "ready to wrap up"
        case blocked = "blocked"
        case inProgress = "in progress"
        case waiting = "waiting"

        var sortOrder: Int {
            switch self {
            case .readyToWrapUp: return 0
            case .blocked: return 1
            case .inProgress: return 2
            case .waiting: return 3
            }
        }
    }

    let title: String
    let state: State
    let stopped: String
    let date: Date

    var id: String { title }

    func isStale(asOf referenceDate: Date = Date()) -> Bool {
        referenceDate.timeIntervalSince(date) > 14 * 86400
    }

    var isStale: Bool {
        isStale(asOf: Date())
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
