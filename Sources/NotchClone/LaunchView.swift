import AppKit
import SwiftUI

struct LaunchView: View {
    @Bindable var launcher: LauncherStore
    @Bindable var shortcuts: ShortcutsService

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Apps")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 16)

                if launcher.pinnedApps.isEmpty {
                    Text("Drag an app here to pin it")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(launcher.pinnedApps, id: \.self) { url in
                                Button {
                                    launcher.launch(url)
                                } label: {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 36, height: 36)
                                }
                                .buttonStyle(.plain)
                                .help(url.deletingPathExtension().lastPathComponent)
                                .contextMenu {
                                    Button("Unpin") {
                                        launcher.unpin(url)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(height: 40)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Shortcuts")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 16)

                if shortcuts.names.isEmpty {
                    Text("No shortcuts found")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 8) {
                            ForEach(shortcuts.names, id: \.self) { name in
                                Button {
                                    shortcuts.run(name)
                                } label: {
                                    HStack(spacing: 6) {
                                        if shortcuts.runningName == name {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                                .frame(width: 12, height: 12)
                                        }
                                        Text(name)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                            .frame(maxWidth: 140)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(height: 28)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.vertical, 6)
        .onAppear {
            shortcuts.reloadIfStale()
        }
    }
}
