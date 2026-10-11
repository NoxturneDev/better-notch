import SwiftUI

struct TabBarView: View {
    @Bindable var model: NotchViewModel

    var body: some View {
        HStack(spacing: 6) {
            ForEach(NotchTab.allCases) { tab in
                Button {
                    model.selectedTab = tab
                } label: {
                    Image(systemName: tab.symbolName)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(model.selectedTab == tab ? 1.0 : 0.45))
                        .frame(width: 24, height: 22)
                }
                .buttonStyle(.plain)
                .help(tab.label)
            }
        }
    }
}
