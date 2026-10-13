import Foundation

struct TaskRow: Identifiable, Equatable, Sendable {
    let plan: PlanSummary
    let agents: [HerdrAgent]
    var id: String { plan.id }
}
