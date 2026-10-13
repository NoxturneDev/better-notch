import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct NotchRootView: View {
    @Bindable var model: NotchViewModel
    let notchSize: CGSize
    let services: AppServices

    var currentSize: CGSize {
        model.isOpen ? NotchGeometry.openSize : NotchGeometry.closedSize(notch: notchSize, showsIndicators: services.showsClosedIndicators)
    }

    var cornerRadius: CGFloat {
        model.isOpen ? 22 : 12
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear

            ZStack(alignment: .top) {
                NotchShape(cornerRadius: cornerRadius)
                    .fill(Color.black)

                if model.isOpen {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            TabBarView(model: model, herdr: services.herdr, today: services.today)
                                .padding(.leading, 14)

                            Spacer(minLength: notchSize.width)

                            StatusStripView(weather: services.weather, battery: services.battery)
                        }
                        .frame(height: notchSize.height)

                        Group {
                            switch model.selectedTab {
                            case .home:
                                HomeView(services: services)
                            case .agents:
                                AgentsView(herdr: services.herdr, plans: services.plans)
                            case .today:
                                TodayView(store: services.today)
                            case .timer:
                                TimerView(service: services.timer)
                            case .notes:
                                NotesView(store: services.notes, model: model)
                            case .launch:
                                LaunchView(launcher: services.launcher, shortcuts: services.shortcuts)
                            case .system:
                                SystemView(stats: services.systemStats, weather: services.weather, model: model)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(model.isOpen ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2).delay(0.1), value: model.isOpen)
                    }
                } else if services.showsClosedIndicators {
                    ClosedIndicatorsView(services: services, notchSize: notchSize)
                }
            }
            .frame(width: currentSize.width, height: currentSize.height)
            .contentShape(NotchShape(cornerRadius: cornerRadius))
            .onHover { hovering in
                model.setHovering(hovering)
            }
            .onDrop(of: [UTType.fileURL], isTargeted: Binding<Bool>(
                get: { model.isDropTargeted },
                set: { targeted in
                    model.setDropTargeted(targeted)
                }
            )) { providers in
                handleDrop(providers: providers)
            }
            .contextMenu {
                Button("Quit NotchClone") {
                    NSApp.terminate(nil)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.isOpen)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: services.showsClosedIndicators)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: services.herdr.waitingCount > 0)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: services.today.readyToWrapUpCount > 0)
        }
        .frame(width: NotchGeometry.windowSize.width, height: NotchGeometry.windowSize.height, alignment: .top)
        .onChange(of: model.isOpen) { _, _ in
            updateActivity()
        }
        .onChange(of: model.selectedTab) { _, _ in
            updateActivity()
        }
    }

    private func updateActivity() {
        services.notchAgentsVisible = model.isOpen && model.selectedTab == .agents
        services.updateAgentsActivity()

        services.notchTodayVisible = model.isOpen && model.selectedTab == .today
        services.updateTodayActivity()

        if model.isOpen {
            services.nowPlaying.startPolling()
            services.battery.refresh()
            services.weather.refreshIfStale()

            if model.selectedTab == .system {
                services.systemStats.start()
            } else {
                services.systemStats.stop()
            }

            if model.selectedTab == .launch {
                services.shortcuts.reloadIfStale()
            }
        } else {
            services.nowPlaying.stopPolling()
            services.systemStats.stop()
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var didAccept = false
        for provider in providers {
            if provider.canLoadObject(ofClass: NSURL.self) {
                _ = provider.loadObject(ofClass: NSURL.self) { item, _ in
                    if let nsURL = item as? NSURL, let url = nsURL as URL? {
                        Task { @MainActor in
                            if model.selectedTab == .launch && url.pathExtension == "app" {
                                services.launcher.pin(url)
                            } else {
                                services.fileTray.add(url)
                                if model.selectedTab != .home {
                                    model.selectedTab = .home
                                }
                            }
                        }
                    }
                }
                didAccept = true
            }
        }
        return didAccept
    }
}
