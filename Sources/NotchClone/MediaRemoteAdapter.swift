import AppKit
import Darwin
import Foundation
import Observation

@MainActor
@Observable
final class MediaRemoteAdapter {
    var currentTrack: Track?
    var artworkImage: NSImage?
    var isRunning: Bool = false
    var onUpdate: (@MainActor () -> Void)?

    @ObservationIgnored
    private nonisolated(unsafe) var process: Process?
    @ObservationIgnored
    private nonisolated(unsafe) var outputPipe: Pipe?
    @ObservationIgnored
    private var restartTask: Task<Void, Never>?
    @ObservationIgnored
    private var successTimerTask: Task<Void, Never>?
    @ObservationIgnored
    private var restartAttempts: Int = 0
    @ObservationIgnored
    private nonisolated(unsafe) var isIntentionalStop: Bool = false
    @ObservationIgnored
    private var currentPayload: [String: Any] = [:]

    init() {
        start()
    }

    deinit {
        isIntentionalStop = true
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        if let proc = process, proc.isRunning {
            proc.terminate()
        }
    }

    func start() {
        guard !isRunning else { return }
        guard let paths = Self.findAdapterPaths() else {
            return
        }

        Self.reapOrphans()

        isIntentionalStop = false
        restartTask?.cancel()
        restartTask = nil

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        proc.arguments = [paths.scriptURL.path, paths.frameworkURL.path, "stream"]

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        let readQueue = DispatchQueue(label: "com.notchclone.mediaremote.reader")
        var buffer = Data()

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            readQueue.async {
                buffer.append(chunk)
                while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                    let lineData = buffer.subdata(in: 0..<newlineIndex)
                    buffer.removeSubrange(0...newlineIndex)
                    if !lineData.isEmpty {
                        if let json = (try? JSONSerialization.jsonObject(with: lineData)) as? [String: Any] {
                            Task { @MainActor [weak self] in
                                self?.handleStreamJSON(json)
                            }
                        }
                    }
                }
            }
        }

        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleTermination()
            }
        }

        do {
            try proc.run()
            self.process = proc
            self.outputPipe = pipe
            self.isRunning = true

            // After running cleanly for 15s, reset backoff attempts
            successTimerTask?.cancel()
            successTimerTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                if !Task.isCancelled {
                    self?.restartAttempts = 0
                }
            }
        } catch {
            self.process = nil
            self.outputPipe = nil
            self.isRunning = false
            scheduleRestart()
        }
    }

    func stop() {
        isIntentionalStop = true
        restartTask?.cancel()
        restartTask = nil
        successTimerTask?.cancel()
        successTimerTask = nil

        outputPipe?.fileHandleForReading.readabilityHandler = nil
        if let proc = process, proc.isRunning {
            proc.terminate()
        }
        process = nil
        outputPipe = nil
        isRunning = false
        currentPayload = [:]
        currentTrack = nil
        artworkImage = nil
        onUpdate?()
    }

    func playPause() {
        send(commandId: 2) // kMRTogglePlayPause
    }

    func next() {
        send(commandId: 4) // kMRNextTrack
    }

    func previous() {
        send(commandId: 5) // kMRPreviousTrack
    }

    func send(commandId: Int) {
        guard let paths = Self.findAdapterPaths() else { return }
        let scriptPath = paths.scriptURL.path
        let frameworkPath = paths.frameworkURL.path

        Task.detached(priority: .userInitiated) {
            Self.runSendCommand(scriptPath: scriptPath, frameworkPath: frameworkPath, commandId: commandId)
        }
    }

    private func handleTermination() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
        outputPipe = nil
        isRunning = false

        if !isIntentionalStop {
            scheduleRestart()
        }
    }

    private func scheduleRestart() {
        restartAttempts += 1
        let delaySeconds = min(Double(1 << min(restartAttempts, 5)), 30.0)

        restartTask?.cancel()
        restartTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            if !Task.isCancelled {
                self?.start()
            }
        }
    }

    private func handleStreamJSON(_ json: [String: Any]) {
        guard let type = json["type"] as? String, type == "data" else { return }
        let isDiff = json["diff"] as? Bool ?? false
        let payload = json["payload"] as? [String: Any] ?? [:]

        if !isDiff {
            currentPayload = payload
        } else {
            for (key, val) in payload {
                if val is NSNull {
                    currentPayload.removeValue(forKey: key)
                } else {
                    currentPayload[key] = val
                }
            }
        }

        updateStateFromCurrentPayload(isDiff: isDiff)
    }

    private func updateStateFromCurrentPayload(isDiff: Bool) {
        guard let title = currentPayload["title"] as? String,
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            currentTrack = nil
            artworkImage = nil
            onUpdate?()
            return
        }

        let artist = currentPayload["artist"] as? String ?? ""
        let isPlaying = currentPayload["playing"] as? Bool ?? false
        let bundleId = currentPayload["bundleIdentifier"] as? String ?? ""

        let source = resolveSource(bundleId: bundleId)
        currentTrack = Track(
            title: title,
            artist: artist,
            isPlaying: isPlaying,
            source: source,
            isFromAdapter: true
        )

        if let base64Art = currentPayload["artworkData"] as? String,
           !base64Art.isEmpty,
           let data = Data(base64Encoded: base64Art, options: .ignoreUnknownCharacters) {
            artworkImage = NSImage(data: data)
        } else if !isDiff && currentPayload["artworkData"] == nil {
            artworkImage = nil
        }
        onUpdate?()
    }

    private func resolveSource(bundleId: String) -> Track.Source {
        if bundleId == "com.spotify.client" {
            return .spotify
        }
        if bundleId == "com.apple.Music" {
            return .music
        }

        var appName = ""
        if !bundleId.isEmpty {
            if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first,
               let name = running.localizedName, !name.isEmpty {
                appName = name
            } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                appName = appURL.deletingPathExtension().lastPathComponent
            } else {
                appName = bundleId.components(separatedBy: ".").last ?? bundleId
            }
        }

        return .generic(bundleId: bundleId, appName: appName.isEmpty ? "Media" : appName)
    }

    private nonisolated static func runSendCommand(scriptPath: String, frameworkPath: String, commandId: Int) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        proc.arguments = [scriptPath, frameworkPath, "send", String(commandId)]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        let deadline = DispatchWorkItem {
            if proc.isRunning {
                proc.terminate()
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 5.0, execute: deadline)

        do {
            try proc.run()
            proc.waitUntilExit()
            deadline.cancel()
        } catch {
            deadline.cancel()
        }
    }

    nonisolated static func reapOrphans() {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-axo", "pid=,ppid=,command="]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        let deadline = DispatchWorkItem {
            if proc.isRunning {
                proc.terminate()
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 5.0, execute: deadline)

        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            deadline.cancel()

            guard let output = String(data: data, encoding: .utf8) else { return }
            let lines = output.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
                guard parts.count >= 3 else { continue }
                guard let pid = Int32(parts[0]), let ppid = Int32(parts[1]) else { continue }
                let command = String(parts[2])

                if ppid == 1 && command.contains("mediaremote-adapter.pl") && command.contains("stream") {
                    kill(pid, SIGTERM)
                }
            }
        } catch {
            deadline.cancel()
        }
    }

    static func findAdapterPaths() -> (scriptURL: URL, frameworkURL: URL)? {
        var candidateDirs: [URL] = []

        if let resURL = Bundle.main.resourceURL {
            candidateDirs.append(resURL.appendingPathComponent("mediaremote-adapter"))
        }
        if let bundleResURL = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: nil) {
            candidateDirs.append(bundleResURL)
        }
        if let execURL = Bundle.main.executableURL {
            let appRes = execURL.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/mediaremote-adapter")
            candidateDirs.append(appRes)
        }
        let cwdRes = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/mediaremote-adapter")
        candidateDirs.append(cwdRes)

        let fm = FileManager.default
        for dir in candidateDirs {
            let script = dir.appendingPathComponent("mediaremote-adapter.pl")
            let framework = dir.appendingPathComponent("MediaRemoteAdapter.framework")
            if fm.fileExists(atPath: script.path) && fm.fileExists(atPath: framework.path) {
                return (scriptURL: script, frameworkURL: framework)
            }
        }
        return nil
    }
}
