import SwiftUI

struct UsageTodayView: View {
    let today: UsageDay?

    private let colors: [Color] = [.blue, .orange, .red, .purple, .teal, .gray]

    private func displayName(for rawName: String) -> String {
        switch rawName.lowercased() {
        case "claude": return "Claude Code"
        case "antigravity": return "Antigravity"
        case "gemini": return "Gemini CLI"
        case "opencode": return "OpenCode"
        case "codex": return "Codex"
        default: return rawName.capitalized
        }
    }

    var body: some View {
        let totalTokens = today?.totalTokens ?? 0
        let totalCost = today?.totalCost ?? 0.0
        let tools = today?.tools ?? []

        VStack(alignment: .leading, spacing: 8) {
            Text("Today: \(TokenFormat.tokens(totalTokens)) tokens · \(TokenFormat.cost(totalCost)) at API prices")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.65))
                .frame(maxWidth: .infinity, alignment: .center)

            if !tools.isEmpty && totalTokens > 0 {
                // 6 pt stacked bar
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        ForEach(Array(tools.enumerated()), id: \.element.id) { index, tool in
                            let fraction = Double(tool.totalTokens) / Double(totalTokens)
                            Rectangle()
                                .fill(colors[index % colors.count])
                                .frame(width: max(1, geo.size.width * fraction))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .frame(height: 6)

                // Tool breakdown rows
                VStack(spacing: 4) {
                    ForEach(Array(tools.enumerated()), id: \.element.id) { index, tool in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colors[index % colors.count])
                                .frame(width: 8, height: 8)

                            Text(displayName(for: tool.name))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white)

                            Spacer()

                            Text(TokenFormat.tokens(tool.totalTokens))
                                .font(.system(size: 11))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.8))

                            Text(TokenFormat.cost(tool.totalCost))
                                .font(.system(size: 11))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.55))
                                .frame(width: 52, alignment: .trailing)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
    }
}
