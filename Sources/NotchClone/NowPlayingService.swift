import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class NowPlayingService {
    var track: Track?
    var artwork: NSImage?

    private var pollTask: Task<Void, Never>?
    private var lastArtworkKey: String?
    private var spotifyObserver: Any?
    private var musicObserver: Any?

    init() {
        spotifyObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }

        musicObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }

        refresh()
    }

    func startPolling() {
        stopPolling()
        refresh()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if Task.isCancelled { break }
                await self?.refreshAsync()
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() {
        Task { [weak self] in
            await self?.refreshAsync()
        }
    }

    private func refreshAsync() async {
        let fetchedTrack = await Task.detached(priority: .userInitiated) { () -> Track? in
            NowPlayingService.fetchNowPlayingOnBackground()
        }.value

        if !Task.isCancelled {
            self.track = fetchedTrack
            updateArtworkIfNeeded(for: fetchedTrack)
        }
    }

    private func updateArtworkIfNeeded(for newTrack: Track?) {
        guard let current = newTrack else {
            self.artwork = nil
            self.lastArtworkKey = nil
            return
        }

        let key = "\(current.source.rawValue)|\(current.title)|\(current.artist)"
        if key != lastArtworkKey {
            lastArtworkKey = key
            Task { [weak self] in
                let img = await Task.detached(priority: .userInitiated) { () -> NSImage? in
                    NowPlayingService.fetchArtworkOnBackground(source: current.source)
                }.value

                if self?.lastArtworkKey == key {
                    self?.artwork = img
                }
            }
        }
    }

    private nonisolated static func fetchArtworkOnBackground(source: Track.Source) -> NSImage? {
        switch source {
        case .spotify:
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client")
            guard !apps.isEmpty else { return nil }
            let scriptSource = "tell application \"Spotify\" to return artwork url of current track"
            var errorInfo: NSDictionary?
            guard let script = NSAppleScript(source: scriptSource) else { return nil }
            let descriptor = script.executeAndReturnError(&errorInfo)
            guard errorInfo == nil, let urlString = descriptor.stringValue, let url = URL(string: urlString) else {
                return nil
            }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return NSImage(data: data)

        case .music:
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music")
            guard !apps.isEmpty else { return nil }
            let scriptSource = "tell application \"Music\" to return raw data of artwork 1 of current track"
            var errorInfo: NSDictionary?
            guard let script = NSAppleScript(source: scriptSource) else { return nil }
            let descriptor = script.executeAndReturnError(&errorInfo)
            guard errorInfo == nil else { return nil }
            let data = descriptor.data
            guard !data.isEmpty else { return nil }
            return NSImage(data: data)
        }
    }

    private nonisolated static func fetchNowPlayingOnBackground() -> Track? {
        let spotifyTrack = fetchTrack(bundleId: "com.spotify.client", appName: "Spotify", source: .spotify)
        let musicTrack = fetchTrack(bundleId: "com.apple.Music", appName: "Music", source: .music)

        if let spotify = spotifyTrack, spotify.isPlaying {
            return spotify
        }
        if let music = musicTrack, music.isPlaying {
            return music
        }
        return spotifyTrack ?? musicTrack
    }

    private nonisolated static func fetchTrack(bundleId: String, appName: String, source: Track.Source) -> Track? {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        guard !apps.isEmpty else { return nil }

        let scriptSource = """
        tell application "\(appName)"
            if player state is stopped then return ""
            return (name of current track) & "|||" & (artist of current track) & "|||" & (player state as string)
        end tell
        """

        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: scriptSource) else { return nil }
        let descriptor = script.executeAndReturnError(&errorInfo)
        guard errorInfo == nil else { return nil }

        guard let output = descriptor.stringValue, !output.isEmpty else { return nil }
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 3 else { return nil }

        let title = parts[0]
        let artist = parts[1]
        let stateStr = parts[2].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isPlaying = (stateStr == "playing")

        return Track(title: title, artist: artist, isPlaying: isPlaying, source: source)
    }

    func playPause() {
        sendCommand("playpause")
    }

    func next() {
        sendCommand("next track")
    }

    func previous() {
        sendCommand("previous track")
    }

    private func sendCommand(_ command: String) {
        let targetApp: String?
        if let currentSource = track?.source {
            targetApp = currentSource.rawValue
        } else {
            if !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty {
                targetApp = "Spotify"
            } else if !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty {
                targetApp = "Music"
            } else {
                targetApp = nil
            }
        }

        guard let appName = targetApp else { return }

        Task { [weak self] in
            await Task.detached(priority: .userInitiated) {
                let scriptSource = "tell application \"\(appName)\" to \(command)"
                var errorInfo: NSDictionary?
                let script = NSAppleScript(source: scriptSource)
                script?.executeAndReturnError(&errorInfo)
            }.value

            self?.refresh()
        }
    }
}
