import Foundation

enum AgentProgressReader {
    nonisolated static func lastProgress(cwd: String) -> AgentProgress? {
        guard let (path, _) = findNewestTranscript(cwd: cwd) else { return nil }
        return readProgress(fromTranscriptPath: path)
    }

    nonisolated static func findNewestTranscript(cwd: String) -> (path: String, mtime: Date)? {
        var sanitized = cwd.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else { return nil }
        sanitized = NSString(string: sanitized).expandingTildeInPath
        while sanitized.count > 1 && sanitized.hasSuffix("/") {
            sanitized.removeLast()
        }

        let folderName = sanitized.replacingOccurrences(of: "/", with: "-")
        let baseDir = NSString(string: "~/.claude/projects").expandingTildeInPath
        let dirPath = (baseDir as NSString).appendingPathComponent(folderName)

        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: dirPath, isDirectory: &isDir), isDir.boolValue else {
            return nil
        }

        guard let files = try? fm.contentsOfDirectory(atPath: dirPath) else {
            return nil
        }

        let jsonlFiles = files.filter { $0.hasSuffix(".jsonl") }
        var newest: (path: String, mtime: Date)? = nil
        for file in jsonlFiles {
            let fullPath = (dirPath as NSString).appendingPathComponent(file)
            let attrs = try? fm.attributesOfItem(atPath: fullPath)
            let mtime = attrs?[.modificationDate] as? Date ?? Date.distantPast
            if newest == nil || mtime > newest!.mtime {
                newest = (fullPath, mtime)
            }
        }
        return newest
    }

    nonisolated static func readProgress(fromTranscriptPath path: String) -> AgentProgress? {
        // Privacy check: only read transcripts under ~/.claude/projects/
        let baseDir = NSString(string: "~/.claude/projects").expandingTildeInPath
        guard path.hasPrefix(baseDir) else { return nil }

        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }

        let fileSize: UInt64
        do {
            fileSize = try handle.seekToEnd()
        } catch {
            return nil
        }
        guard fileSize > 0 else { return nil }

        let maxTailBytes: UInt64 = 256 * 1024
        let startOffset = fileSize > maxTailBytes ? fileSize - maxTailBytes : 0
        do {
            try handle.seek(toOffset: startOffset)
        } catch {
            return nil
        }

        let tailData: Data
        do {
            tailData = try handle.readToEnd() ?? Data()
        } catch {
            return nil
        }

        guard let content = String(data: tailData, encoding: .utf8) ?? String(data: tailData, encoding: .isoLatin1) else {
            return nil
        }

        var lines = content.components(separatedBy: .newlines)
        if startOffset > 0 && !lines.isEmpty {
            lines.removeFirst()
        }

        // 1. Scan backwards for away_summary
        for line in lines.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if trimmed.contains("\"subtype\":\"away_summary\"") {
                if let progress = parseAwaySummary(line: trimmed) {
                    return progress
                }
            }
        }

        // 2. Fallback: Scan backwards for last assistant text message
        for line in lines.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if trimmed.contains("\"type\":\"assistant\"") || trimmed.contains("\"role\":\"assistant\"") {
                if let progress = parseAssistantMessage(line: trimmed) {
                    return progress
                }
            }
        }

        return nil
    }

    nonisolated static func parseDate(_ string: String) -> Date? {
        let isoWithFrac = ISO8601DateFormatter()
        isoWithFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoWithFrac.date(from: string) { return d }
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: string) { return d }
        return nil
    }

    nonisolated static func parseAwaySummary(line: String) -> AgentProgress? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let subtype = json["subtype"] as? String, subtype == "away_summary",
              let content = json["content"] as? String else {
            return nil
        }

        let rawDate = json["timestamp"] as? String
        let date = rawDate.flatMap { parseDate($0) }

        var text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasSuffix(" (disable recaps in /config)") {
            text = String(text.dropLast(" (disable recaps in /config)".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !text.isEmpty else { return nil }
        return AgentProgress(text: text, date: date, isRecap: true)
    }

    nonisolated static func parseAssistantMessage(line: String) -> AgentProgress? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let isAssistant = (json["type"] as? String == "assistant") ||
            ((json["message"] as? [String: Any])?["role"] as? String == "assistant")
        guard isAssistant else { return nil }

        var extractedText: String? = nil

        if let message = json["message"] as? [String: Any] {
            if let contentArray = message["content"] as? [[String: Any]] {
                for block in contentArray {
                    if block["type"] as? String == "text", let t = block["text"] as? String, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        extractedText = t.trimmingCharacters(in: .whitespacesAndNewlines)
                        break
                    }
                }
            } else if let s = message["content"] as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                extractedText = s.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if extractedText == nil, let s = json["content"] as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            extractedText = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if extractedText == nil, let t = json["text"] as? String, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            extractedText = t.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let text = extractedText, !text.isEmpty else { return nil }

        let rawDate = json["timestamp"] as? String
        let date = rawDate.flatMap { parseDate($0) }

        let truncated: String
        if text.count > 200 {
            let prefix = String(text.prefix(200))
            truncated = prefix.trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        } else {
            truncated = text
        }

        return AgentProgress(text: truncated, date: date, isRecap: false)
    }
}
