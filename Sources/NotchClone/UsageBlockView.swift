import SwiftUI

struct UsageBlockView: View {
    let block: UsageBlock

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let remainingSeconds = max(0, block.end.timeIntervalSince(timeline.date))
            let hours = Int(remainingSeconds) / 3600
            let minutes = (Int(remainingSeconds) % 3600) / 60
            let resetText = hours > 0 ? "Resets in \(hours) h \(minutes) min" : "Resets in \(minutes) min"

            let totalSpan = max(1, block.end.timeIntervalSince(block.start))
            let elapsed = max(0, min(totalSpan, timeline.date.timeIntervalSince(block.start)))
            let progress = elapsed / totalSpan

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(resetText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)

                    Spacer()

                    Text("\(TokenFormat.tokens(block.totalTokens)) · \(TokenFormat.cost(block.cost))")
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.7))
                }

                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(.blue)

                Text("at API prices")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}
