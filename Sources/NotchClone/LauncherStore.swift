import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class LauncherStore {
    private let key = "pinnedAppPaths"
    var pinnedApps: [URL] = []

    init() {
        if let stored = UserDefaults.standard.array(forKey: key) as? [String] {
            self.pinnedApps = stored.compactMap { path in
                let url = URL(fileURLWithPath: path)
                return FileManager.default.fileExists(atPath: url.path) ? url : nil
            }
        } else {
            let bundleIds = [
                "com.apple.Safari",
                "com.apple.Terminal",
                "com.apple.systempreferences",
                "com.apple.finder"
            ]
            let defaultUrls = bundleIds.compactMap {
                NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
            }
            self.pinnedApps = defaultUrls
            save()
        }
    }

    private func save() {
        let paths = pinnedApps.map { $0.path }
        UserDefaults.standard.set(paths, forKey: key)
    }

    func pin(_ url: URL) {
        guard url.pathExtension == "app" else { return }
        let standard = url.standardizedFileURL
        guard !pinnedApps.contains(where: { $0.standardizedFileURL == standard }) else { return }
        pinnedApps.append(standard)
        save()
    }

    func unpin(_ url: URL) {
        let standard = url.standardizedFileURL
        pinnedApps.removeAll(where: { $0.standardizedFileURL == standard })
        save()
    }

    func launch(_ url: URL) {
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
