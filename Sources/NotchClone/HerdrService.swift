import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class HerdrService {
    var agents: [HerdrAgent] = []
    var workspaces: [HerdrWorkspace] = []
    var isAvailable = false
    var waitingCount: Int {
        agents.filter(\.isWaiting).count
    }
    var workingCount: Int {
        agents.filter { $0.status == .working }.count
    }

    private var isFastPolling = false
    private var pollingTask: Task<Void, Never>?

    init() {
        startPolling()
    }

    func setFastPolling(_ fast: Bool) {
        guard isFastPolling != fast else { return }
        isFastPolling = fast
        pollingTask?.cancel()
        startPolling()
    }

    func focus(_ agent: HerdrAgent) {
        guard let binary = HerdrService.findBinary() else { return }
        Task {
            _ = await Task.detached(priority: .userInitiated) {
                HerdrService.runTool(binary: binary, arguments: ["agent", "focus", agent.id])
            }.value

            let bundleId = UserDefaults.standard.string(forKey: "terminalBundleId") ?? "com.mitchellh.ghostty"
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                NSWorkspace.shared.openApplication(at: appURL, configuration: config, completionHandler: nil)
            }
        }
    }

    func refresh() async {
        guard let binary = HerdrService.findBinary() else {
            if isAvailable || !agents.isEmpty || !workspaces.isEmpty {
                isAvailable = false
                agents = []
                workspaces = []
            }
            return
        }

        let fetched = await Task.detached(priority: .userInitiated) {
            HerdrService.fetchSnapshot(binary: binary)
        }.value

        if let fetched {
            isAvailable = true
            if agents != fetched.agents {
                agents = fetched.agents
            }
            if workspaces != fetched.workspaces {
                workspaces = fetched.workspaces
            }
        } else {
            isAvailable = false
            if !agents.isEmpty {
                agents = []
            }
            if !workspaces.isEmpty {
                workspaces = []
            }
        }
    }

    private func startPolling() {
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                let interval: UInt64 = (self?.isFastPolling == true) ? 5 : 15
                do {
                    try await Task.sleep(nanoseconds: interval * 1_000_000_000)
                } catch {
                    break
                }
            }
        }
    }

    nonisolated static func findBinary() -> String? {
        let candidates = [
            NSString(string: "~/.local/bin/herdr").expandingTildeInPath,
            "/opt/homebrew/bin/herdr",
            "/usr/local/bin/herdr"
        ]
        let fm = FileManager.default
        for path in candidates {
            if fm.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    private nonisolated static func runTool(binary: String, arguments: [String]) -> Data? {
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
        DispatchQueue.global().asyncAfter(deadline: .now() + 5, execute: deadline)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        deadline.cancel()
        guard process.terminationStatus == 0 else { return nil }
        return data
    }

    struct SnapshotResult: Sendable {
        let agents: [HerdrAgent]
        let workspaces: [HerdrWorkspace]
    }

    private nonisolated static func fetchSnapshot(binary: String) -> SnapshotResult? {
        guard let data = runTool(binary: binary, arguments: ["api", "snapshot"]) else {
            return nil
        }

        do {
            let decoded = try JSONDecoder().decode(SnapshotEnvelope.self, from: data)
            let rawWorkspaces = decoded.result.snapshot.workspaces ?? []
            let rawTabs = decoded.result.snapshot.tabs ?? []
            let rawAgents = decoded.result.snapshot.agents ?? []

            let tabsByWorkspace = Dictionary(grouping: rawTabs, by: { $0.workspace_id })
            let workspaces = rawWorkspaces.map { rw in
                let tabs = (tabsByWorkspace[rw.workspace_id] ?? [])
                    .sorted { $0.number < $1.number }
                    .map { rt in
                        HerdrTab(
                            id: rt.tab_id,
                            workspaceId: rt.workspace_id,
                            number: rt.number,
                            paneCount: rt.pane_count,
                            label: rt.label
                        )
                    }
                return HerdrWorkspace(id: rw.workspace_id, label: rw.label, tabs: tabs)
            }

            let workspaceMap = Dictionary(workspaces.map { ($0.id, $0.label) }, uniquingKeysWith: { first, _ in first })

            let agents = rawAgents.map { raw in
                HerdrAgent(
                    id: raw.pane_id,
                    kind: raw.agent,
                    status: HerdrAgent.Status(rawValue: raw.agent_status),
                    name: raw.name,
                    cwd: raw.cwd ?? "",
                    workspaceId: raw.workspace_id,
                    workspaceLabel: workspaceMap[raw.workspace_id] ?? raw.workspace_id,
                    tabId: raw.tab_id ?? "",
                    title: raw.terminal_title_stripped
                )
            }

            return SnapshotResult(agents: agents, workspaces: workspaces)
        } catch {
            return nil
        }
    }
}

private struct SnapshotEnvelope: Decodable {
    struct ResultObj: Decodable {
        struct SnapshotObj: Decodable {
            struct RawAgent: Decodable {
                let agent: String
                let agent_status: String
                let cwd: String?
                let name: String?
                let pane_id: String
                let workspace_id: String
                let tab_id: String?
                let terminal_title_stripped: String?
            }

            struct RawTab: Decodable {
                let tab_id: String
                let workspace_id: String
                let number: Int
                let pane_count: Int
                let label: String?
            }

            struct RawWorkspace: Decodable {
                let workspace_id: String
                let label: String
            }

            let agents: [RawAgent]?
            let workspaces: [RawWorkspace]?
            let tabs: [RawTab]?
        }

        let snapshot: SnapshotObj
    }

    let result: ResultObj
}
