import SwiftUI

struct AgentsPopoverView: View {
    let services: AppServices
    var onFocus: ((HerdrAgent) -> Void)? = nil

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .short
        return df
    }()

    private func popoverSectionHeader(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.4))
            Spacer()
        }
        .padding(.top, 4)
    }

    var body: some View {
        let board = AgentBoard(agents: services.herdr.agents, workspaces: services.herdr.workspaces, plans: services.plans.plans, progressByAgentId: services.herdr.progressByAgentId)
        let idleCount = services.herdr.agents.filter { $0.status == .idle }.count

        VStack(spacing: 12) {
            // Title row
            Text("Agents")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .center)

            // Summary ring
            AgentRingView(
                waiting: services.herdr.waitingCount,
                working: services.herdr.workingCount,
                idle: idleCount
            )

            Divider()
                .overlay(Color.white.opacity(0.12))

            // Scrollable content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 12) {
                    // Usage section
                    if !services.usage.isAvailable {
                        Text("Usage unavailable (ccusage not found)")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else if services.usage.days.isEmpty && services.usage.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        // USAGE HISTORY
                        popoverSectionHeader("USAGE HISTORY")
                        UsageHistoryChart(days: services.usage.days)

                        Divider()
                            .overlay(Color.white.opacity(0.12))

                        // TODAY
                        popoverSectionHeader("TODAY")
                        UsageTodayView(today: services.usage.today)

                        // CLAUDE USAGE WINDOW
                        if let block = services.usage.activeBlock {
                            Divider()
                                .overlay(Color.white.opacity(0.12))

                            popoverSectionHeader("CLAUDE USAGE WINDOW")
                            UsageBlockView(block: block)
                        }
                    }

                    Divider()
                        .overlay(Color.white.opacity(0.12))

                    // Agent lists
                    AgentListSections(
                        board: board,
                        herdr: services.herdr,
                        headerStyle: .centeredUppercase,
                        onFocus: { agent in
                            services.herdr.focus(agent)
                            onFocus?(agent)
                        }
                    )

                    // Footer line
                    if let last = services.usage.lastUpdated {
                        Text("Updated \(Self.timeFormatter.string(from: last))")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.35))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                            .padding(.bottom, 6)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(14)
        .frame(width: 360, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
