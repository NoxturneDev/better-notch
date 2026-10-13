import Foundation

enum NotchTab: String, CaseIterable, Identifiable {
    case home, agents, today, timer, notes, launch, system
    var id: String { rawValue }
    var symbolName: String {
        switch self {
        case .home: "music.note"
        case .agents: "terminal"
        case .today: "checklist"
        case .timer: "timer"
        case .notes: "note.text"
        case .launch: "square.grid.2x2"
        case .system: "cpu"
        }
    }
    var label: String { rawValue.capitalized }
}
