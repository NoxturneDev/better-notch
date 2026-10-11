import Foundation

struct ToolUsage: Identifiable, Equatable, Sendable {
    var id: String { name }
    let name: String
    let totalTokens: Int
    let totalCost: Double
}

struct UsageDay: Identifiable, Equatable, Sendable {
    var id: Date { date }
    let date: Date
    let totalTokens: Int
    let totalCost: Double
    let tools: [ToolUsage]
}
