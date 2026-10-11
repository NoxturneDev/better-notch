import SwiftUI

struct NowPlayingView: View {
    @Bindable var service: NowPlayingService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let track = service.track {
                HStack(spacing: 12) {
                    if let artwork = service.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(track.artist)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                HStack(spacing: 16) {
                    Button {
                        service.previous()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Button {
                        service.playPause()
                    } label: {
                        Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Button {
                        service.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nothing playing")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))

                    HStack(spacing: 16) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.3))
                        Image(systemName: "play.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.3))
                        Image(systemName: "forward.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
