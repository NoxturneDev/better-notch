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

    var body: some View {
        if board.projects.isEmpty {
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
            VStack(alignment: .leading, spacing: 8) {
                ForEach(board.projects) { card in
                    ProjectCardView(card: card, herdr: herdr, onFocus: onFocus)
                }
            }
        }
    }
}
