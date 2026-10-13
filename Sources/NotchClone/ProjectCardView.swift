import SwiftUI

struct ProjectCardView: View {
    let card: ProjectCard
    var herdr: HerdrService
    var onFocus: ((HerdrAgent) -> Void)? = nil

    @State private var isProgressExpanded: Bool = false

    private func triggerFocus(_ agent: HerdrAgent) {
        if let onFocus {
            onFocus(agent)
        } else {
            herdr.focus(agent)
        }
    }

    private func handleTaskTap(_ task: TaskRow) {
        if let waiting = task.agents.first(where: \.isWaiting) {
            triggerFocus(waiting)
        } else if let first = task.agents.first {
            triggerFocus(first)
        } else if let lead = card.lead {
            triggerFocus(lead)
        }
    }

    private func statusColor(_ status: ProjectCard.Status) -> Color {
        switch status {
        case .waitingForYou:
            return .orange
        case .working:
            return .green
        case .readyToWrapUp:
            return .green
        case .idle:
            return .gray
        case .notStarted:
            return .gray.opacity(0.5)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Project name + status
            HStack(spacing: 6) {
                Text(card.projectName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor(card.status))
                        .frame(width: 6, height: 6)

                    Text(card.status.displayText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            // Lead row (Decision 4 & 5)
            if let lead = card.lead {
                Button {
                    triggerFocus(lead)
                } label: {
                    HStack(alignment: .center, spacing: 6) {
                        Text("Lead")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(width: 44, alignment: .leading)

                        let title = (lead.title?.isEmpty == false) ? "Claude · \"\(lead.title!)\"" : "Claude"
                        Text(title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Focus Lead (Claude)")

                if let progress = card.leadProgress {
                    HStack(alignment: .top, spacing: 6) {
                        Color.clear
                            .frame(width: 44, height: 1)

                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isProgressExpanded.toggle()
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 4) {
                                Group {
                                    if let age = progress.relativeAge {
                                        Text(age + " · ")
                                            .foregroundStyle(.white.opacity(0.45))
                                        + Text(progress.text)
                                            .foregroundStyle(.white.opacity(0.7))
                                    } else {
                                        Text(progress.text)
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                }
                                .font(.system(size: 11, weight: .regular))
                                .lineLimit(isProgressExpanded ? nil : 3)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)

                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(isProgressExpanded ? "Click to collapse" : "Click to expand")
                    }
                }
            }

            // Task blocks
            ForEach(card.tasks) { task in
                Button {
                    handleTaskTap(task)
                } label: {
                    HStack(alignment: .top, spacing: 6) {
                        Text("Task")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(width: 44, alignment: .leading)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(task.plan.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                Spacer(minLength: 6)

                                if task.plan.isReadyToWrapUp {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.green)
                                } else {
                                    let total = task.plan.doneCount + task.plan.openCount
                                    Text("\(task.plan.doneCount)/\(total)")
                                        .font(.system(size: 9))
                                        .monospacedDigit()
                                        .foregroundStyle(.white.opacity(0.7))

                                    ProgressView(value: task.plan.fraction)
                                        .progressViewStyle(.linear)
                                        .tint(.green)
                                        .frame(width: 44)
                                }
                            }

                            if !task.plan.next.isEmpty {
                                Text("Next: \(task.plan.next)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.55))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            // Workers count line (Decision 1)
            if card.workerCounts.total > 0 {
                HStack(spacing: 6) {
                    Text("Workers:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 44, alignment: .leading)

                    Text(card.workerCounts.summaryText)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.65))

                    Spacer()
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}
