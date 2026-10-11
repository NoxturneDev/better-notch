import Charts
import SwiftUI

struct UsageHistoryChart: View {
    let days: [UsageDay]

    private static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE"
        return df
    }()

    private var totalTokens: Int {
        days.reduce(0) { $0 + $1.totalTokens }
    }

    private var totalCost: Double {
        days.reduce(0.0) { $0 + $1.totalCost }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Chart(days) { day in
                let isToday = Calendar.current.isDateInToday(day.date)
                BarMark(
                    x: .value("Day", Self.dayFormatter.string(from: day.date)),
                    y: .value("Tokens", day.totalTokens)
                )
                .foregroundStyle(isToday ? Color.blue : Color.blue.opacity(0.5))
                .cornerRadius(3)
            }
            .frame(height: 90)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.08))
                    AxisValueLabel {
                        if let intVal = value.as(Int.self) {
                            Text(TokenFormat.tokens(intVal))
                                .font(.system(size: 9))
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(size: 9))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }

            Text("7 days: \(TokenFormat.tokens(totalTokens)) tokens · \(TokenFormat.cost(totalCost)) at API prices")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.65))
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
