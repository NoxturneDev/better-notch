import Foundation
import Observation

@MainActor
@Observable
final class FileTrayStore {
    var files: [URL] = []

    func add(_ url: URL) {
        let standardURL = url.standardizedFileURL
        if !files.contains(where: { $0.standardizedFileURL == standardURL }) {
            files.append(standardURL)
        }
    }

    func add(_ urls: [URL]) {
        for url in urls {
            add(url)
        }
    }

    func remove(_ url: URL) {
        let standardURL = url.standardizedFileURL
        files.removeAll(where: { $0.standardizedFileURL == standardURL })
    }

    func clear() {
        files.removeAll()
    }
}
