import Foundation

struct ProjectCard: Identifiable, Sendable {
    struct WorkerCounts: Equatable, Sendable {
        let working: Int
        let idle: Int
        let waiting: Int

        var total: Int { working + idle + waiting }

        var summaryText: String {
            var parts: [String] = []
            if waiting > 0 {
                parts.append("\(waiting) waiting for you")
            }
            if working > 0 {
                parts.append("\(working) working")
            }
            if idle > 0 {
                parts.append("\(idle) idle")
            }
            return parts.isEmpty ? "0 workers" : parts.joined(separator: " · ")
        }
    }

    enum Status: Equatable, Sendable {
        case waitingForYou
        case working
        case readyToWrapUp
        case idle
        case notStarted

        var displayText: String {
            switch self {
            case .waitingForYou: return "waiting for you"
            case .working: return "working"
            case .readyToWrapUp: return "ready to wrap up"
            case .idle: return "idle"
            case .notStarted: return "not started"
            }
        }

        var sortRank: Int {
            switch self {
            case .waitingForYou: return 0
            case .working: return 1
            case .readyToWrapUp: return 2
            case .idle: return 3
            case .notStarted: return 4
            }
        }
    }

    var id: String {
        workspace?.id ?? "no_active_session_\(projectName)"
    }

    let projectName: String
    let workspace: HerdrWorkspace?
    let lead: HerdrAgent?
    let leadProgress: AgentProgress?
    let tasks: [TaskRow]
    let workerCounts: WorkerCounts
    let status: Status

    init(
        projectName: String,
        workspace: HerdrWorkspace?,
        lead: HerdrAgent?,
        leadProgress: AgentProgress? = nil,
        tasks: [TaskRow],
        workerCounts: WorkerCounts,
        status: Status
    ) {
        self.projectName = projectName
        self.workspace = workspace
        self.lead = lead
        self.leadProgress = leadProgress
        self.tasks = tasks
        self.workerCounts = workerCounts
        self.status = status
    }
}
