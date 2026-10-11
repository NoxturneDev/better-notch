import Foundation
import Observation

@MainActor
@Observable
final class NotesStore {
    var text: String {
        didSet {
            scheduleSave()
        }
    }

    private let fileURL: URL
    private var saveTask: Task<Void, Never>?

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let folder = appSupport.appendingPathComponent("NotchClone")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("notes.txt")
        self.fileURL = file

        if let content = try? String(contentsOf: file, encoding: .utf8) {
            self.text = content
        } else {
            self.text = ""
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    func flush() {
        saveTask?.cancel()
        saveTask = nil
        try? text.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
