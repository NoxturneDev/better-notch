import Foundation

enum TokenFormat {
    static func tokens(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000.0)
        } else if n >= 1_000 {
            return String(format: "%.0fK", Double(n) / 1_000.0)
        } else {
            return "\(n)"
        }
    }

    static func cost(_ v: Double) -> String {
        return String(format: "$%.2f", v)
    }
}
