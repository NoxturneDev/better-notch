import SwiftUI

struct HerdrMapView: View {
    var herdr: HerdrService
    var plans: [PlanSummary]
    var onFocus: ((HerdrAgent) -> Void)? = nil

    @State private var isExpanded: Bool = false

    private func triggerFocus(_ agent: HerdrAgent) {
        if let onFocus {
            onFocus(agent)
        } else {
            herdr.focus(agent)
        }
    }

    var body: some View {
        let workspaceCount = herdr.workspaces.count
        let tabCount = herdr.workspaces.reduce(0) { $0 + $1.tabs.count }
        let paneCount = herdr.workspaces.reduce(0) { sum, ws in
            sum + ws.tabs.reduce(0) { $0 + $1.paneCount }
        }

        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))

                    Text("Herdr map (\(workspaceCount) workspaces · \(tabCount) tabs · \(paneCount) panes)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(herdr.workspaces) { ws in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ws.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))

                            ForEach(ws.tabs) { tab in
                                let tabAgents = herdr.agents.filter { $0.tabId == tab.id }
                                HerdrTabRowView(
                                    tab: tab,
                                    agents: tabAgents,
                                    plans: plans,
                                    onFocus: { triggerFocus($0) }
                                )
                            }
                        }
                        .padding(.leading, 8)
                    }
                }
                .padding(.top, 2)
                .padding(.bottom, 6)
            }
        }
    }
}

private struct HerdrTabRowView: View {
    let tab: HerdrTab
    let agents: [HerdrAgent]
    let plans: [PlanSummary]
    let onFocus: (HerdrAgent) -> Void

    private var lead: HerdrAgent? {
        agents.first(where: { $0.kind == "claude" })
    }

    private var matchedTaskTitle: String? {
        let agentNames = Set(agents.compactMap { $0.name } + agents.map { $0.displayName })
        for plan in plans {
            if plan.workers.contains(where: { agentNames.contains($0) }) {
                return plan.title
            }
        }
        return nil
    }

    private var workersSummary: String {
        let working = agents.filter { $0.status == .working }.count
        let idle = agents.filter { $0.status == .idle }.count
        let waiting = agents.filter { $0.isWaiting }.count
        var countParts: [String] = []
        if waiting > 0 { countParts.append("\(waiting) waiting") }
        if working > 0 { countParts.append("\(working) working") }
        if idle > 0 { countParts.append("\(idle) idle") }
        let subtext = countParts.joined(separator: " · ")
        return "\(agents.count) workers (\(subtext))"
    }

    private func statusColor(_ status: HerdrAgent.Status) -> Color {
        switch status {
        case .blocked, .done: return .orange
        case .working: return .green
        case .idle: return .gray
        case .unknown: return .gray.opacity(0.5)
        }
    }

    var body: some View {
        Button {
            if let lead {
                onFocus(lead)
            } else if let first = agents.first {
                onFocus(first)
            }
        } label: {
            HStack(spacing: 8) {
                Text("tab \(tab.number)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 36, alignment: .leading)

                HStack(spacing: 4) {
                    if let lead {
                        Circle()
                            .fill(statusColor(lead.status))
                            .frame(width: 5, height: 5)
                        Text("Claude (\(lead.status.rawValue))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    } else if !agents.isEmpty {
                        Text(workersSummary)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.75))
                    } else {
                        Text("\(tab.paneCount) panes")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }

                if let title = matchedTaskTitle {
                    Text("→")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.35))

                    Text(title)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
