import AppKit
import SwiftUI

struct ClosedIndicatorsView: View {
    let services: AppServices
    let notchSize: CGSize

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if services.nowPlaying.track?.isPlaying == true {
                    if let artwork = services.nowPlaying.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 20, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                    }
                } else {
                    Color.clear
                }
            }
            .frame(width: NotchGeometry.indicatorWidth, height: notchSize.height)

            Color.clear
                .frame(width: notchSize.width, height: notchSize.height)

            Group {
                if services.timer.isRunning {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        if let label = services.timer.closedLabel(at: timeline.date) {
                            Text(label)
                                .font(.system(size: 11, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                        }
                    }
                } else if services.nowPlaying.track?.isPlaying == true {
                    Image(systemName: "waveform")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .symbolEffect(.variableColor.iterative)
                } else {
                    Color.clear
                }
            }
            .frame(width: NotchGeometry.indicatorWidth, height: notchSize.height)
        }
        .frame(height: notchSize.height)
    }
}
