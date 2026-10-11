import Foundation

struct TaskRow: Identifiable, Equatable {
    let plan: PlanSummary
    let agents: [HerdrAgent]
    var id: String { plan.id }
}

struct AgentBoard: Sendable {
    let tasks: [TaskRow]
    let readyToWrapUp: [TaskRow]
    let otherAgents: [HerdrAgent]

    init(agents: [HerdrAgent], plans: [PlanSummary], now: Date = Date()) {
        let liveAgentsByName = Dictionary(grouping: agents.filter { $0.name != nil }, by: { $0.name! })
        let fourteenDaysAgo = now.addingTimeInterval(-14 * 24 * 3600)

        // Visible per Key Design Decision 5:
        // Not closed AND (has a live worker OR modified in last 14 days)
        let visiblePlans = plans.filter { plan in
            guard !plan.isClosed else { return false }
            let hasLiveWorker = plan.workers.contains { liveAgentsByName[$0] != nil }
            return hasLiveWorker || plan.modified >= fourteenDaysAgo
        }

        var visibleWorkerNames = Set<String>()
        for plan in visiblePlans {
            visibleWorkerNames.formUnion(plan.workers)
        }

        let readyRows: [TaskRow] = visiblePlans
            .filter { $0.isReadyToWrapUp }
            .map { plan in
                let matchedAgents = plan.workers.compactMap { liveAgentsByName[$0] }.flatMap { $0 }
                return TaskRow(plan: plan, agents: matchedAgents)
            }
            .sorted { $0.plan.modified > $1.plan.modified }

        self.readyToWrapUp = readyRows

        let taskRows: [TaskRow] = visiblePlans
            .filter { !$0.isReadyToWrapUp }
            .map { plan in
                let matchedAgents = plan.workers.compactMap { liveAgentsByName[$0] }.flatMap { $0 }
                return TaskRow(plan: plan, agents: matchedAgents)
            }

        self.tasks = taskRows.sorted { a, b in
            let rankA = Self.taskRank(a)
            let rankB = Self.taskRank(b)
            if rankA != rankB {
                return rankA < rankB
            }
            return a.plan.modified > b.plan.modified
        }

        // Other agents: not named in any visible plan's workers; idle ones dropped
        self.otherAgents = agents
            .filter { agent in
                if let name = agent.name, visibleWorkerNames.contains(name) {
                    return false
                }
                return agent.status != .idle
            }
            .sorted { a, b in
                let rankA = a.isWaiting ? 0 : (a.status == .working ? 1 : 2)
                let rankB = b.isWaiting ? 0 : (b.status == .working ? 1 : 2)
                if rankA != rankB {
                    return rankA < rankB
                }
                return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
            }
    }

    private static func taskRank(_ row: TaskRow) -> Int {
        if row.agents.contains(where: \.isWaiting) {
            return 0
        }
        if row.agents.contains(where: { $0.status == .working }) {
            return 1
        }
        return 2
    }
}
