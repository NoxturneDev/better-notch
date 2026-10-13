import AppKit
import SwiftUI

struct TodayView: View {
    @Bindable var store: TodayStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.fileNotFound {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Today.md not found")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                    }
                    Spacer()
                }
            } else if store.items.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Nothing in flight")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                    }
                    Spacer()
                }
            } else {
                HStack {
                    Text("\(store.items.count) in flight · \(store.readyToWrapUpCount) ready to wrap up")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    if store.isUpdatedStale, let days = store.updatedDaysAgo {
                        Text("updated \(days) day\(days == 1 ? "" : "s") ago")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.orange)
                    }
                }
                .padding(.horizontal, 8)

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(store.sortedItems) { item in
                            Button {
                                openInObsidian(item.title)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(alignment: .center, spacing: 6) {
                                        Text(item.title)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                            .truncationMode(.tail)

                                        Spacer()

                                        if item.isStale {
                                            staleChip
                                        }

                                        stateChip(item.state)
                                    }

                                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                                        Text(item.stopped)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.white.opacity(0.75))
                                            .lineLimit(2)
                                            .truncationMode(.tail)

                                        Spacer(minLength: 8)

                                        Text(item.formattedDate)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.white.opacity(0.4))
                                            .monospacedDigit()
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Open in Obsidian")
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func stateColor(_ state: TodayItem.State) -> Color {
        switch state {
        case .readyToWrapUp:
            return .green
        case .inProgress:
            return .blue
        case .blocked:
            return .red
        case .waiting:
            return .orange
        }
    }

    private func stateChip(_ state: TodayItem.State) -> some View {
        let color = stateColor(state)
        return Text(state.rawValue)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private var staleChip: some View {
        Text("stale")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.15))
            .clipShape(Capsule())
    }

    private func openInObsidian(_ title: String) {
        let customVault = UserDefaults.standard.string(forKey: "obsidianVaultName")
        let vaultName = (customVault?.isEmpty == false) ? customVault! : "my-notes"

        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "vault", value: vaultName),
            URLQueryItem(name: "file", value: title)
        ]
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }
}
