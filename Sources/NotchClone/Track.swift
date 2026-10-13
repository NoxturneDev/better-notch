import Foundation

struct Track: Equatable, Sendable {
    enum Source: Equatable, Sendable, CustomStringConvertible {
        case spotify
        case music
        case generic(bundleId: String, appName: String)

        var displayName: String {
            switch self {
            case .spotify:
                return "Spotify"
            case .music:
                return "Music"
            case .generic(_, let appName):
                return appName.isEmpty ? "Media" : appName
            }
        }

        var rawValue: String {
            switch self {
            case .spotify:
                return "Spotify"
            case .music:
                return "Music"
            case .generic(let bundleId, let appName):
                return "\(bundleId)|\(appName)"
            }
        }

        var description: String {
            return displayName
        }
    }

    let title: String
    let artist: String
    let isPlaying: Bool
    let source: Source
    let isFromAdapter: Bool

    init(title: String, artist: String, isPlaying: Bool, source: Source, isFromAdapter: Bool = false) {
        self.title = title
        self.artist = artist
        self.isPlaying = isPlaying
        self.source = source
        self.isFromAdapter = isFromAdapter
    }
}
