import SwiftUI

struct TaskRowView: View {
    let task: TaskRow
    var herdr: HerdrService
    var showCheckmark: Bool = false
    var onFocus: ((HerdrAgent) -> Void)? = nil

    private var rowStateColor: Color {
        if task.agents.contains(where: \.isWaiting) {
            return .orange
        }
        if task.agents.contains(where: { $0.status == .working }) {
            return .green
        }
        return .gray
    }

    private func handleRowTap() {
        if let waiting = task.agents.first(where: \.isWaiting) {
            triggerFocus(waiting)
        } else if let first = task.agents.first {
            triggerFocus(first)
        }
    }

    private func triggerFocus(_ agent: HerdrAgent) {
        if let onFocus {
            onFocus(agent)
        } else {
            herdr.focus(agent)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Line 1: State dot · project · title · Spacer · (done/total & progress OR checkmark)
            HStack(spacing: 6) {
                Circle()
                    .fill(rowStateColor)
                    .frame(width: 6, height: 6)

                Text(task.plan.project)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)

                Text("·")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.35))

                Text(task.plan.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                if showCheckmark {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                } else {
                    let total = task.plan.doneCount + task.plan.openCount
                    Text("\(task.plan.doneCount)/\(total)")
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.7))

                    ProgressView(value: task.plan.fraction)
                        .progressViewStyle(.linear)
                        .tint(.green)
                        .frame(width: 60)
                }
            }

            // Line 2: next (10 pt, white 0.55, 1 line) · Spacer · agent capsules
            HStack(spacing: 6) {
                if !task.plan.next.isEmpty {
                    Text(task.plan.next)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    if task.agents.count <= 3 {
                        ForEach(task.agents) { agent in
                            Button {
                                triggerFocus(agent)
                            } label: {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(statusColor(agent.status))
                                        .frame(width: 4, height: 4)
                                    Text(agent.displayName)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.85))
                                        .lineLimit(1)
                                        .fixedSize()
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.12))
                                )
                            }
                            .buttonStyle(.plain)
                            .help("Focus \(agent.displayName)")
                        }
                    } else {
                        ForEach(task.agents) { agent in
                            Button {
                                triggerFocus(agent)
                            } label: {
                                Circle()
                                    .fill(statusColor(agent.status))
                                    .frame(width: 8, height: 8)
                                    .frame(width: 14, height: 14)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("\(agent.displayName) — \(statusWord(agent.status))")
                        }

                        if !agentsSummaryText.isEmpty {
                            Text(agentsSummaryText)
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.55))
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                }
                .fixedSize()
                .layoutPriority(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.001)) // hit-testable
        )
        .contentShape(Rectangle())
        .onTapGesture {
            handleRowTap()
        }
    }

    private var agentsSummaryText: String {
        let waitingCount = task.agents.filter(\.isWaiting).count
        let workingCount = task.agents.filter { $0.status == .working }.count
        let idleCount = task.agents.filter { $0.status == .idle }.count

        var parts: [String] = []
        if waitingCount > 0 {
            parts.append("\(waitingCount) waiting")
        }
        if workingCount > 0 {
            parts.append("\(workingCount) working")
        }
        if idleCount > 0 {
            parts.append("\(idleCount) idle")
        }
        return parts.joined(separator: " · ")
    }

    private func statusWord(_ status: HerdrAgent.Status) -> String {
        switch status {
        case .blocked:
            return "blocked"
        case .done:
            return "done"
        case .working:
            return "working"
        case .idle:
            return "idle"
        case .unknown:
            return "unknown"
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
}
