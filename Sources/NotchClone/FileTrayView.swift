import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FileTrayView: View {
    @Bindable var store: FileTrayStore

    var body: some View {
        Group {
            if store.files.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("Drop files here")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 4) {
                    HStack(spacing: 12) {
                        Spacer()

                        Button {
                            if let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: store.files) {
                                service.perform(withItems: store.files)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                Text("AirDrop")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                        }
                        .buttonStyle(.plain)

                        Button {
                            store.clear()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "xmark.circle")
                                Text("Clear")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 2)

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 10) {
                            ForEach(store.files, id: \.self) { url in
                                VStack(spacing: 4) {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 32, height: 32)

                                    Text(url.lastPathComponent)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .truncationMode(.middle)
                                        .frame(width: 68)
                                }
                                .frame(width: 72, height: 74)
                                .padding(4)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onDrag {
                                    NSItemProvider(object: url as NSURL)
                                }
                                .contextMenu {
                                    Button("Remove from tray") {
                                        store.remove(url)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
