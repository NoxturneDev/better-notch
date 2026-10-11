import Foundation
import Observation

@MainActor
@Observable
final class ShortcutsService {
    var names: [String] = []
    var runningName: String?
    private var lastLoaded: Date?

    func reloadIfStale() {
        if let last = lastLoaded, Date().timeIntervalSince(last) < 60 {
            return
        }

        Task { [weak self] in
            let output = await Task.detached(priority: .userInitiated) {
                ShortcutsService.runTool(["list"])
            }.value

            if let out = output {
                let lines = out.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                self?.names = lines
                self?.lastLoaded = Date()
            }
        }
    }

    func run(_ name: String) {
        runningName = name
        Task { [weak self] in
            _ = await Task.detached(priority: .userInitiated) {
                ShortcutsService.runTool(["run", name])
            }.value

            if self?.runningName == name {
                self?.runningName = nil
            }
        }
    }

    private nonisolated static func runTool(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}
