import SwiftUI

struct AgentRingView: View {
    let waiting: Int
    let working: Int
    let idle: Int

    var total: Int {
        waiting + working + idle
    }

    private var waitingFraction: Double {
        total > 0 ? Double(waiting) / Double(total) : 0
    }

    private var workingFraction: Double {
        total > 0 ? Double(working) / Double(total) : 0
    }

    private var idleFraction: Double {
        total > 0 ? Double(idle) / Double(total) : 0
    }

    var body: some View {
        HStack(spacing: 16) {
            // 64 pt Ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 6)

                if total > 0 {
                    // Waiting (Orange)
                    if waiting > 0 {
                        Circle()
                            .trim(from: 0, to: waitingFraction)
                            .stroke(Color.orange, style: StrokeStyle(lineWidth: 6, lineCap: .butt))
                            .rotationEffect(.degrees(-90))
                    }

                    // Working (Green)
                    if working > 0 {
                        Circle()
                            .trim(from: waitingFraction, to: waitingFraction + workingFraction)
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .butt))
                            .rotationEffect(.degrees(-90))
                    }

                    // Idle (Grey)
                    if idle > 0 {
                        Circle()
                            .trim(from: waitingFraction + workingFraction, to: 1.0)
                            .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 6, lineCap: .butt))
                            .rotationEffect(.degrees(-90))
                    }
                }

                // Middle waiting count
                VStack(spacing: 0) {
                    Text("\(waiting)")
                        .font(.system(size: 16, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 64, height: 64)

            // Legend
            VStack(alignment: .leading, spacing: 4) {
                legendItem(color: .orange, label: "Waiting", count: waiting)
                legendItem(color: .green, label: "Working", count: working)
                legendItem(color: .gray, label: "Idle", count: idle)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 4)
    }

    private func legendItem(color: Color, label: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))

            Spacer()

            Text("\(count)")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }
}
