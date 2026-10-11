import Foundation

struct HerdrAgent: Identifiable, Equatable, Sendable {
    enum Status: String, Sendable {
        case working
        case idle
        case done
        case blocked
        case unknown

        init(rawValue: String) {
            switch rawValue {
            case "working": self = .working
            case "idle": self = .idle
            case "done": self = .done
            case "blocked": self = .blocked
            default: self = .unknown
            }
        }
    }

    let id: String            // pane_id
    let kind: String          // "claude", "agy", …
    let status: Status        // unknown for any value not listed
    let name: String?
    let cwd: String
    let workspaceLabel: String
    let title: String?

    var isWaiting: Bool { status == .blocked || status == .done }
    var displayName: String { name ?? title ?? kind }
}
