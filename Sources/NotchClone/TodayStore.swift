import Foundation
import Observation

@MainActor
@Observable
final class TodayStore {
    var items: [TodayItem] = []
    var updated: Date? = nil
    var fileNotFound: Bool = false

    var readyToWrapUpCount: Int {
        items.filter { $0.state == .readyToWrapUp }.count
    }

    var hasStaleItems: Bool {
        items.contains { $0.isStale }
    }

    var isUpdatedStale: Bool {
        guard let updated else { return false }
        return Date().timeIntervalSince(updated) > 2 * 86400
    }

    var updatedDaysAgo: Int? {
        guard let updated else { return nil }
        let days = Calendar.current.dateComponents([.day], from: updated, to: Date()).day ?? 0
        return max(0, days)
    }

    var showsTabDot: Bool {
        readyToWrapUpCount > 0 || hasStaleItems || isUpdatedStale
    }

    var sortedItems: [TodayItem] {
        items.sorted { a, b in
            if a.isStale != b.isStale {
                return !a.isStale && b.isStale
            }
            if a.state.sortOrder != b.state.sortOrder {
                return a.state.sortOrder < b.state.sortOrder
            }
            if a.date != b.date {
                return a.date > b.date
            }
            return a.title < b.title
        }
    }

    private var isTabVisible: Bool = false
    private var pollTask: Task<Void, Never>?
    private var lastModified: Date?

    init() {
        start()
    }

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.reload()
                let intervalSec: UInt64 = (self?.isTabVisible == true) ? 30 : 60
                do {
                    try await Task.sleep(nanoseconds: intervalSec * 1_000_000_000)
                } catch {
                    break
                }
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func setTabVisible(_ visible: Bool) {
        guard isTabVisible != visible else { return }
        isTabVisible = visible
        pollTask?.cancel()
        pollTask = nil
        start()
    }

    func reload() async {
        let path = TodayStore.resolveFilePath()
        let inspection = await Task.detached(priority: .userInitiated) { () -> (exists: Bool, mtime: Date?) in
            let fm = FileManager.default
            guard fm.fileExists(atPath: path) else {
                return (false, nil)
            }
            let attrs = try? fm.attributesOfItem(atPath: path)
            let mtime = attrs?[.modificationDate] as? Date
            return (true, mtime)
        }.value

        guard inspection.exists else {
            if !fileNotFound || !items.isEmpty || updated != nil {
                fileNotFound = true
                items = []
                updated = nil
                lastModified = nil
            }
            return
        }

        if let mtime = inspection.mtime, let lastModified, mtime == lastModified {
            return
        }

        let parsed = await Task.detached(priority: .userInitiated) { () -> (Date?, [TodayItem])? in
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
                return nil
            }
            return TodayStore.parse(content)
        }.value

        fileNotFound = false
        lastModified = inspection.mtime
        if let (newUpdated, newItems) = parsed {
            updated = newUpdated
            items = newItems
        }
    }

    static func resolveFilePath() -> String {
        let custom = UserDefaults.standard.string(forKey: "todayFilePath")
        let raw = custom?.isEmpty == false ? custom! : "~/Projects/my-notes/Today.md"
        return NSString(string: raw).expandingTildeInPath
    }

    nonisolated static func parseDate(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: trimmed) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: trimmed) { return d }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current

        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd"
        ]
        for format in formats {
            df.dateFormat = format
            if let d = df.date(from: trimmed) { return d }
        }
        return nil
    }

    nonisolated static func parse(_ content: String) -> (updated: Date?, items: [TodayItem]) {
        let lines = content.components(separatedBy: .newlines)
        guard !lines.isEmpty else { return (nil, []) }

        var updated: Date?
        var frontmatterLines: [String] = []
        var bodyLines: [String] = []

        let trimmedFirst = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedFirst == "---" {
            var endIdx: Int?
            for i in 1..<lines.count {
                if lines[i].trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
                    endIdx = i
                    break
                }
            }
            if let end = endIdx {
                frontmatterLines = Array(lines[1..<end])
                bodyLines = Array(lines[(end + 1)...])
            } else {
                bodyLines = lines
            }
        } else {
            bodyLines = lines
        }

        for fLine in frontmatterLines {
            guard let colonIdx = fLine.firstIndex(of: ":") else { continue }
            let key = fLine[..<colonIdx].trimmingCharacters(in: .whitespaces)
            let value = fLine[fLine.index(after: colonIdx)...]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if key == "updated" {
                updated = parseDate(value)
            }
        }

        let pattern = #"^\s*-\s*\[\[([^\]]+)\]\]\s*[—–-]+\s*\*\*([^*]+)\*\*\s*[—–-]+\s*(.+?)\s*\(([0-9]{4}-[0-9]{2}-[0-9]{2})\)\s*$"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])

        var inFlight = false
        var items: [TodayItem] = []

        for line in bodyLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                let headerTitle = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "#")).trimmingCharacters(in: .whitespaces)
                if headerTitle.caseInsensitiveCompare("In flight") == .orderedSame {
                    inFlight = true
                    continue
                } else if inFlight {
                    break
                }
            }

            guard inFlight, let regex else { continue }

            let nsString = line as NSString
            let fullRange = NSRange(location: 0, length: nsString.length)
            guard let match = regex.firstMatch(in: line, options: [], range: fullRange), match.numberOfRanges == 5 else {
                continue
            }

            let rawTitle = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            let rawState = nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces).lowercased()
            let rawStopped = nsString.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespaces)
            let rawDate = nsString.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)

            guard let state = TodayItem.State(rawValue: rawState),
                  let date = parseDate(rawDate) else {
                continue
            }

            items.append(TodayItem(
                title: rawTitle,
                state: state,
                stopped: rawStopped,
                date: date
            ))
        }

        return (updated, items)
    }
}
