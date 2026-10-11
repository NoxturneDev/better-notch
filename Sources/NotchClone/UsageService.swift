import Foundation
import Observation

@MainActor
@Observable
final class UsageService {
    var days: [UsageDay] = []
    var activeBlock: UsageBlock?
    var isAvailable = true
    var lastUpdated: Date?
    var isLoading = false

    var today: UsageDay? {
        let cal = Calendar.current
        return days.first(where: { cal.isDateInToday($0.date) })
    }

    private var pollTask: Task<Void, Never>?

    func start() {
        guard pollTask == nil else { return }
        refresh()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                } catch {
                    break
                }
                if Task.isCancelled { break }
                await self?.refreshAsync()
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() {
        Task { [weak self] in
            await self?.refreshAsync()
        }
    }

    private func refreshAsync() async {
        guard let bun = Self.findBunBinary(), let script = Self.findCcusageScript() else {
            isAvailable = false
            return
        }

        isAvailable = true
        isLoading = true
        defer { isLoading = false }

        let result = await Task.detached(priority: .userInitiated) {
            Self.fetchUsage(bun: bun, script: script)
        }.value

        if let fetchedDays = result.days {
            self.days = fetchedDays
            self.lastUpdated = Date()
        }
        if let fetchedBlock = result.block {
            self.activeBlock = fetchedBlock
            self.lastUpdated = Date()
        } else if result.hadBlockQuery {
            self.activeBlock = nil
        }
    }

    nonisolated static func findBunBinary() -> String? {
        let candidates = [
            NSString(string: "~/.bun/bin/bun").expandingTildeInPath,
            "/opt/homebrew/bin/bun",
            "/usr/local/bin/bun"
        ]
        let fm = FileManager.default
        for path in candidates {
            if fm.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    nonisolated static func findCcusageScript() -> String? {
        let path = NSString(string: "~/.bun/bin/ccusage").expandingTildeInPath
        if FileManager.default.fileExists(atPath: path) {
            return path
        }
        return nil
    }

    private nonisolated static func runTool(binary: String, arguments: [String], timeoutSeconds: Double = 20) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        let deadline = DispatchWorkItem {
            if process.isRunning {
                process.terminate()
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds, execute: deadline)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        deadline.cancel()
        guard process.terminationStatus == 0 else { return nil }
        return data
    }

    private struct FetchResult: Sendable {
        let days: [UsageDay]?
        let block: UsageBlock?
        let hadBlockQuery: Bool
    }

    private nonisolated static func fetchUsage(bun: String, script: String) -> FetchResult {
        var parsedDays: [UsageDay]?
        var parsedBlock: UsageBlock?
        var hadBlockQuery = false

        if let dailyData = runTool(binary: bun, arguments: [script, "daily", "--json", "--last", "7", "--by-agent", "--offline"]) {
            if let decoded = try? JSONDecoder().decode(RawDailyEnvelope.self, from: dailyData) {
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "yyyy-MM-dd"
                dayFormatter.timeZone = TimeZone.current

                var items: [UsageDay] = []
                for rawDay in decoded.daily ?? [] {
                    guard let date = dayFormatter.date(from: rawDay.period) else { continue }
                    let tools: [ToolUsage] = (rawDay.agents ?? []).map {
                        ToolUsage(
                            name: $0.agent,
                            totalTokens: $0.totalTokens ?? 0,
                            totalCost: $0.totalCost ?? 0.0
                        )
                    }
                    items.append(UsageDay(
                        date: date,
                        totalTokens: rawDay.totalTokens ?? 0,
                        totalCost: rawDay.totalCost ?? 0.0,
                        tools: tools
                    ))
                }
                items.sort { $0.date < $1.date }
                parsedDays = items
            }
        }

        if let blocksData = runTool(binary: bun, arguments: [script, "blocks", "--json", "--active", "--offline"]) {
            hadBlockQuery = true
            if let decoded = try? JSONDecoder().decode(RawBlocksEnvelope.self, from: blocksData) {
                let isoFractional = ISO8601DateFormatter()
                isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let isoStandard = ISO8601DateFormatter()
                isoStandard.formatOptions = [.withInternetDateTime]

                let parseISO = { (s: String) -> Date? in
                    isoFractional.date(from: s) ?? isoStandard.date(from: s)
                }

                if let rawBlock = (decoded.blocks ?? []).first(where: { $0.isActive == true }) ?? decoded.blocks?.first,
                   let startStr = rawBlock.startTime, let start = parseISO(startStr),
                   let endStr = rawBlock.endTime, let end = parseISO(endStr) {
                    parsedBlock = UsageBlock(
                        start: start,
                        end: end,
                        totalTokens: rawBlock.totalTokens ?? 0,
                        cost: rawBlock.costUSD ?? 0.0,
                        remainingMinutes: rawBlock.projection?.remainingMinutes
                    )
                }
            }
        }

        return FetchResult(days: parsedDays, block: parsedBlock, hadBlockQuery: hadBlockQuery)
    }
}

private struct RawDailyEnvelope: Decodable {
    struct RawDay: Decodable {
        let period: String
        let totalTokens: Int?
        let totalCost: Double?
        struct RawAgent: Decodable {
            let agent: String
            let totalTokens: Int?
            let totalCost: Double?
        }
        let agents: [RawAgent]?
    }
    let daily: [RawDay]?
}

private struct RawBlocksEnvelope: Decodable {
    struct RawBlock: Decodable {
        let isActive: Bool?
        let startTime: String?
        let endTime: String?
        let totalTokens: Int?
        let costUSD: Double?
        struct RawProjection: Decodable {
            let remainingMinutes: Int?
        }
        let projection: RawProjection?
    }
    let blocks: [RawBlock]?
}
