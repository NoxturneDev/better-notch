import Foundation

struct PlanSummary: Identifiable, Equatable, Sendable {
    let id: String             // file path
    let project: String        // folder name under projects/
    let title: String          // first "# " line, trailing " [STATUS]" removed; fallback = file name
    let status: String         // frontmatter status, uppercased, "" when missing
    let next: String           // frontmatter next, surrounding quotes removed
    let workers: [String]      // frontmatter workers: [a, b]
    let doneCount: Int         // lines matching ^\s*- \[[xX]\]
    let openCount: Int         // lines matching ^\s*- \[ \]
    let modified: Date

    var isClosed: Bool { status == "COMPLETED" || status == "DONE" }
    var isReadyToWrapUp: Bool { !isClosed && openCount == 0 && doneCount > 0 }
    var fraction: Double { doneCount + openCount == 0 ? 0 : Double(doneCount) / Double(doneCount + openCount) }
}
