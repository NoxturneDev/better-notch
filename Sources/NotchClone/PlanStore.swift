import Foundation
import Observation

@MainActor
@Observable
final class PlanStore {
    var plans: [PlanSummary] = []

    private var scanTask: Task<Void, Never>?

    func start() {
        guard scanTask == nil else { return }
        scanTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.scan()
                do {
                    try await Task.sleep(nanoseconds: 30_000_000_000)
                } catch {
                    break
                }
            }
        }
    }

    func stop() {
        scanTask?.cancel()
        scanTask = nil
    }

    func scan() async {
        let rootPath = PlanStore.resolveRootPath()
        let scanned = await Task.detached(priority: .userInitiated) {
            PlanStore.scanVault(at: rootPath)
        }.value

        if plans != scanned {
            plans = scanned
        }
    }

    static func resolveRootPath() -> String {
        let custom = UserDefaults.standard.string(forKey: "vaultProjectsPath")
        let raw = custom?.isEmpty == false ? custom! : "~/Projects/my-notes/projects"
        return NSString(string: raw).expandingTildeInPath
    }

    nonisolated static func scanVault(at rootPath: String) -> [PlanSummary] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: rootPath, isDirectory: &isDir), isDir.boolValue else {
            return []
        }

        guard let projectNames = try? fm.contentsOfDirectory(atPath: rootPath) else {
            return []
        }

        var results: [PlanSummary] = []

        for projectName in projectNames {
            let planDir = (rootPath as NSString).appendingPathComponent("\(projectName)/plan")
            var isPlanDir: ObjCBool = false
            guard fm.fileExists(atPath: planDir, isDirectory: &isPlanDir), isPlanDir.boolValue else {
                continue
            }

            guard let planFiles = try? fm.contentsOfDirectory(atPath: planDir) else {
                continue
            }

            for file in planFiles {
                guard file.hasSuffix(".md") else { continue }
                let filePath = (planDir as NSString).appendingPathComponent(file)

                var isRegular: ObjCBool = false
                guard fm.fileExists(atPath: filePath, isDirectory: &isRegular), !isRegular.boolValue else {
                    continue
                }

                guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
                    continue
                }

                let attributes = try? fm.attributesOfItem(atPath: filePath)
                let modified = attributes?[.modificationDate] as? Date ?? Date()

                if let summary = parsePlan(filePath: filePath, project: projectName, content: content, modified: modified),
                   !summary.isClosed {
                    results.append(summary)
                }
            }
        }

        return results
    }

    nonisolated static func parsePlan(filePath: String, project: String, content: String, modified: Date) -> PlanSummary? {
        let lines = content.components(separatedBy: .newlines)
        guard !lines.isEmpty else { return nil }

        var frontmatterLines: [String] = []
        var bodyLines: [String] = []

        if lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
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

        var status = ""
        var next = ""
        var workers: [String] = []

        for fLine in frontmatterLines {
            guard let colonIdx = fLine.firstIndex(of: ":") else { continue }
            let key = fLine[..<colonIdx].trimmingCharacters(in: .whitespaces)
            let value = fLine[fLine.index(after: colonIdx)...].trimmingCharacters(in: .whitespaces)
            switch key {
            case "status":
                status = value.uppercased().trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            case "next":
                next = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            case "workers":
                let stripped = value.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                workers = stripped.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
                    .filter { !$0.isEmpty }
            default:
                break
            }
        }

        var title: String?
        var doneCount = 0
        var openCount = 0

        for line in bodyLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if title == nil, trimmed.hasPrefix("# ") {
                var rawTitle = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if let bracketStart = rawTitle.range(of: " [", options: .backwards),
                   rawTitle.hasSuffix("]") {
                    rawTitle = String(rawTitle[..<bracketStart.lowerBound]).trimmingCharacters(in: .whitespaces)
                }
                title = rawTitle
            }

            if trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]") {
                doneCount += 1
            } else if trimmed.hasPrefix("- [ ]") {
                openCount += 1
            }
        }

        let fallbackTitle = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
        let finalTitle = (title?.isEmpty == false) ? title! : fallbackTitle

        return PlanSummary(
            id: filePath,
            project: project,
            title: finalTitle,
            status: status,
            next: next,
            workers: workers,
            doneCount: doneCount,
            openCount: openCount,
            modified: modified
        )
    }
}
