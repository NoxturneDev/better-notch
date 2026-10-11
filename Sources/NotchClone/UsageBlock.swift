import Foundation

struct UsageBlock: Equatable, Sendable {
    let start: Date
    let end: Date
    let totalTokens: Int
    let cost: Double
    let remainingMinutes: Int?
}
