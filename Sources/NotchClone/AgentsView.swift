import SwiftUI

struct AgentsView: View {
    @Bindable var herdr: HerdrService
    @Bindable var plans: PlanStore

    var body: some View {
        let board = AgentBoard(agents: herdr.agents, workspaces: herdr.workspaces, plans: plans.plans)

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
            } else {
                Text("⚠ \(board.needsYouCount) needs you · ● \(board.workingCount) working · ✓ \(board.readyToWrapUpCount) ready to wrap up")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 8)

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(board.projects) { card in
                            ProjectCardView(card: card, herdr: herdr)
                        }

                        HerdrMapView(herdr: herdr, plans: plans.plans)
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
