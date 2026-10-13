import Foundation

struct HerdrWorkspace: Identifiable, Equatable, Sendable {
    let id: String         // workspace_id
    let label: String
    let tabs: [HerdrTab]
}
