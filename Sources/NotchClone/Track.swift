import Foundation

struct Track: Equatable, Sendable {
    enum Source: String, Sendable {
        case spotify = "Spotify"
        case music = "Music"
    }

    let title: String
    let artist: String
    let isPlaying: Bool
    let source: Source
}
