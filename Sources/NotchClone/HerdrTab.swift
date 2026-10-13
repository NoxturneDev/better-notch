import Foundation

struct HerdrTab: Identifiable, Equatable, Sendable {
    let id: String         // tab_id
    let workspaceId: String
    let number: Int
    let paneCount: Int
    let label: String?
}
