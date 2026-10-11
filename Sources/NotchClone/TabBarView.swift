import SwiftUI

struct TabBarView: View {
    @Bindable var model: NotchViewModel
    var herdr: HerdrService

    var body: some View {
        HStack(spacing: 6) {
            ForEach(NotchTab.allCases) { tab in
                Button {
                    model.selectedTab = tab
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: tab.symbolName)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(model.selectedTab == tab ? 1.0 : 0.45))
                            .frame(width: 24, height: 22)

                        if tab == .agents && herdr.waitingCount > 0 {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 5, height: 5)
                                .offset(x: -2, y: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help(tab.label)
            }
        }
    }
}
