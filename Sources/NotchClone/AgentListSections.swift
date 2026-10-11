import SwiftUI

struct AgentListSections: View {
    enum HeaderStyle {
        case standard
        case centeredUppercase
    }

    let board: AgentBoard
    var herdr: HerdrService
    var headerStyle: HeaderStyle = .standard
    var onFocus: ((HerdrAgent) -> Void)? = nil

    private func focus(_ agent: HerdrAgent) {
        if let onFocus {
            onFocus(agent)
        } else {
            herdr.focus(agent)
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        switch headerStyle {
        case .standard:
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.horizontal, 8)
        case .centeredUppercase:
            HStack {
                Spacer()
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
            }
            .padding(.vertical, 2)
        }
    }

    var body: some View {
        if board.tasks.isEmpty && board.otherAgents.isEmpty && board.readyToWrapUp.isEmpty {
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
            .frame(minHeight: 60)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                if !board.tasks.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        sectionHeader("Tasks")

                        ForEach(board.tasks) { task in
                            TaskRowView(task: task, herdr: herdr, showCheckmark: false, onFocus: onFocus)
                        }
                    }
                }

                if !board.readyToWrapUp.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        sectionHeader("Ready to wrap up (\(board.readyToWrapUp.count))")

                        ForEach(board.readyToWrapUp) { task in
                            TaskRowView(task: task, herdr: herdr, showCheckmark: true, onFocus: onFocus)
                        }
                    }
                }

                if !board.otherAgents.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        sectionHeader("Other agents")

                        ForEach(board.otherAgents) { agent in
                            Button {
                                focus(agent)
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
