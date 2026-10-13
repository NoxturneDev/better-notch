import Foundation

struct AgentBoard: Sendable {
    let projects: [ProjectCard]
    let needsYouCount: Int
    let workingCount: Int
    let readyToWrapUpCount: Int

    init(agents: [HerdrAgent], workspaces: [HerdrWorkspace] = [], plans: [PlanSummary], now: Date = Date()) {
        let liveAgentsByName = Dictionary(grouping: agents.filter { $0.name != nil }, by: { $0.name! })
        let fourteenDaysAgo = now.addingTimeInterval(-14 * 24 * 3600)

        // Visible per Key Design Decision 5:
        // Not closed AND (has a live worker OR modified in last 14 days)
        let visiblePlans = plans.filter { plan in
            guard !plan.isClosed else { return false }
            let hasLiveWorker = plan.workers.contains { liveAgentsByName[$0] != nil }
            return hasLiveWorker || plan.modified >= fourteenDaysAgo
        }

        // Match each visible plan to a workspace_id (Key Decision 3)
        var plansByWorkspaceId: [String: [PlanSummary]] = [:]
        var unassignedPlans: [PlanSummary] = []

        for plan in visiblePlans {
            var matchedWsId: String? = nil

            // 1. Through live worker
            for workerName in plan.workers {
                if let matched = agents.first(where: { $0.name == workerName || $0.displayName == workerName }),
                   !matched.workspaceId.isEmpty {
                    matchedWsId = matched.workspaceId
                    break
                }
            }

            // 2. Fallback: plan.project vs workspace label
            if matchedWsId == nil {
                if let ws = workspaces.first(where: { $0.label.lowercased() == plan.project.lowercased() }) {
                    matchedWsId = ws.id
                }
            }

            // 3. Fallback: plan.project vs agent cwd last path component
            if matchedWsId == nil {
                if let agent = agents.first(where: {
                    URL(fileURLWithPath: $0.cwd).lastPathComponent.lowercased() == plan.project.lowercased()
                }), !agent.workspaceId.isEmpty {
                    matchedWsId = agent.workspaceId
                }
            }

            if let wsId = matchedWsId {
                plansByWorkspaceId[wsId, default: []].append(plan)
            } else {
                unassignedPlans.append(plan)
            }
        }

        let agentsByWorkspaceId = Dictionary(grouping: agents, by: { $0.workspaceId })
        var cards: [ProjectCard] = []

        for ws in workspaces {
            let wsAgents = agentsByWorkspaceId[ws.id] ?? []
            let wsPlans = plansByWorkspaceId[ws.id] ?? []

            // If workspace has neither agents nor plans, omit it
            if wsAgents.isEmpty && wsPlans.isEmpty {
                continue
            }

            // Lead per Decision 4: kind == "claude" in that workspace
            let claudeAgents = wsAgents.filter { $0.kind == "claude" }
            let nonClaudeAgents = wsAgents.filter { $0.kind != "claude" }
            let workerTabIds = Set(nonClaudeAgents.map { $0.tabId })

            let lead: HerdrAgent?
            if claudeAgents.count == 1 {
                lead = claudeAgents.first
            } else if claudeAgents.count > 1 {
                if let sameTab = claudeAgents.first(where: { workerTabIds.contains($0.tabId) }) {
                    lead = sameTab
                } else if let nonIdle = claudeAgents.first(where: { $0.status != .idle }) {
                    lead = nonIdle
                } else {
                    lead = claudeAgents.first
                }
            } else {
                lead = nil
            }

            // Workers in that workspace (non-lead)
            let wsWorkers = wsAgents.filter { $0.id != lead?.id }
            let workingCount = wsWorkers.filter { $0.status == .working }.count
            let idleCount = wsWorkers.filter { $0.status == .idle }.count
            let waitingCount = wsWorkers.filter { $0.isWaiting }.count
            let workerCounts = ProjectCard.WorkerCounts(
                working: workingCount,
                idle: idleCount,
                waiting: waitingCount
            )

            // Tasks for this workspace
            let wsTaskRows: [TaskRow] = wsPlans.map { plan in
                let matchedAgents = plan.workers.compactMap { liveAgentsByName[$0] }.flatMap { $0 }
                return TaskRow(plan: plan, agents: matchedAgents)
            }.sorted { a, b in
                let rankA = Self.taskRank(a)
                let rankB = Self.taskRank(b)
                if rankA != rankB {
                    return rankA < rankB
                }
                return a.plan.modified > b.plan.modified
            }

            // Status per Decision 6
            let status: ProjectCard.Status
            if lead?.isWaiting == true || workerCounts.waiting > 0 || wsTaskRows.contains(where: { $0.agents.contains(where: \.isWaiting) }) {
                status = .waitingForYou
            } else if lead?.status == .working || workerCounts.working > 0 || wsTaskRows.contains(where: { $0.agents.contains(where: { $0.status == .working }) }) {
                status = .working
            } else if !wsTaskRows.isEmpty && wsTaskRows.allSatisfy({ $0.plan.isReadyToWrapUp }) {
                status = .readyToWrapUp
            } else if lead != nil || workerCounts.total > 0 {
                status = .idle
            } else {
                status = .notStarted
            }

            cards.append(ProjectCard(
                projectName: ws.label,
                workspace: ws,
                lead: lead,
                tasks: wsTaskRows,
                workerCounts: workerCounts,
                status: status
            ))
        }

        // Unassigned plans (No active session)
        if !unassignedPlans.isEmpty {
            let unassignedTaskRows: [TaskRow] = unassignedPlans.map { plan in
                TaskRow(plan: plan, agents: [])
            }.sorted { a, b in
                let rankA = Self.taskRank(a)
                let rankB = Self.taskRank(b)
                if rankA != rankB {
                    return rankA < rankB
                }
                return a.plan.modified > b.plan.modified
            }

            let status: ProjectCard.Status = unassignedTaskRows.allSatisfy({ $0.plan.isReadyToWrapUp }) ? .readyToWrapUp : .notStarted
            cards.append(ProjectCard(
                projectName: "No active session",
                workspace: nil,
                lead: nil,
                tasks: unassignedTaskRows,
                workerCounts: ProjectCard.WorkerCounts(working: 0, idle: 0, waiting: 0),
                status: status
            ))
        }

        // Sort per Decision 7: waiting for you first, then working, then rest
        cards.sort { a, b in
            if a.workspace == nil && b.workspace != nil { return false }
            if a.workspace != nil && b.workspace == nil { return true }

            if a.status.sortRank != b.status.sortRank {
                return a.status.sortRank < b.status.sortRank
            }
            return a.projectName.localizedCaseInsensitiveCompare(b.projectName) == .orderedAscending
        }

        self.projects = cards
        self.needsYouCount = cards.filter { $0.status == .waitingForYou }.count
        self.workingCount = cards.filter { $0.status == .working }.count
        self.readyToWrapUpCount = cards.filter { card in
            card.status == .readyToWrapUp || card.tasks.contains { $0.plan.isReadyToWrapUp }
        }.count
    }

    static func taskRank(_ row: TaskRow) -> Int {
        if row.agents.contains(where: \.isWaiting) {
            return 0
        }
        if row.agents.contains(where: { $0.status == .working }) {
            return 1
        }
        return 2
    }
}
