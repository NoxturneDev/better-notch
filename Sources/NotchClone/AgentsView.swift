import SwiftUI

struct AgentsView: View {
    @Bindable var herdr: HerdrService
    @Bindable var plans: PlanStore

    var body: some View {
        let board = AgentBoard(agents: herdr.agents, plans: plans.plans)

        VStack(alignment: .leading, spacing: 8) {
            if !herdr.isAvailable {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("herdr is not running")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                    }
                    Spacer()
                }
            } else if board.tasks.isEmpty && board.otherAgents.isEmpty && board.readyToWrapUp.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("No active plans or agents")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                    }
                    Spacer()
                }
            } else {
                Text("\(herdr.waitingCount) waiting · \(herdr.workingCount) working · \(board.readyToWrapUp.count) ready to wrap up")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 8)

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 10) {
                        if !board.tasks.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tasks")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .padding(.horizontal, 8)

                                ForEach(board.tasks) { task in
                                    TaskRowView(task: task, herdr: herdr)
                                }
                            }
                        }

                        if !board.readyToWrapUp.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Ready to wrap up (\(board.readyToWrapUp.count))")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .padding(.horizontal, 8)

                                ForEach(board.readyToWrapUp) { task in
                                    TaskRowView(task: task, herdr: herdr, showCheckmark: true)
                                }
                            }
                        }

                        if !board.otherAgents.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Other agents")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .padding(.horizontal, 8)

                                ForEach(board.otherAgents) { agent in
                                    Button {
                                        herdr.focus(agent)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(statusColor(agent.status))
                                                .frame(width: 6, height: 6)

                                            Text(agent.displayName)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(.white)
                                                .lineLimit(1)

                                            Text(agent.workspaceLabel)
                                                .font(.system(size: 10))
                                                .foregroundStyle(.white.opacity(0.55))
                                                .lineLimit(1)

                                            Spacer()

                                            Text(statusLabel(agent.status))
                                                .font(.system(size: 10))
                                                .foregroundStyle(.white.opacity(0.6))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func statusColor(_ status: HerdrAgent.Status) -> Color {
        switch status {
        case .blocked, .done:
            return .orange
        case .working:
            return .green
        case .idle:
            return .gray
        case .unknown:
            return .secondary
        }
    }

    private func statusLabel(_ status: HerdrAgent.Status) -> String {
        switch status {
        case .blocked: return "Blocked"
        case .done: return "Done"
        case .working: return "Working"
        case .idle: return "Idle"
        case .unknown: return "Unknown"
        }
    }
}
