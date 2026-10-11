import SwiftUI

struct HomeView: View {
    let services: AppServices

    var body: some View {
        HStack(spacing: 0) {
            NowPlayingView(service: services.nowPlaying)
                .frame(width: 230, alignment: .leading)
                .padding(.leading, 18)
                .padding(.trailing, 12)

            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1)
                .padding(.vertical, 8)

            FileTrayView(store: services.fileTray)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 10)
    }
}
