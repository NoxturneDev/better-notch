import AppKit
import SwiftUI

@MainActor
final class NotchWindowController {
    let screen: NSScreen
    let notchSize: CGSize
    let model: NotchViewModel
    let panel: NotchPanel
    let services: AppServices

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var resignKeyObserver: Any?

    init(screen: NSScreen, notchSize: CGSize, services: AppServices) {
        self.screen = screen
        self.notchSize = notchSize
        self.services = services
        let model = NotchViewModel()
        self.model = model

        let size = NotchGeometry.windowSize
        let rect = NSRect(x: (screen.frame.width - size.width) / 2,
                          y: screen.frame.height - size.height,
                          width: size.width, height: size.height)
        let panel = NotchPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel],
                               backing: .buffered, defer: false, screen: screen)
        panel.level = .statusBar                      // 25
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle,
                                    .fullScreenAuxiliary, .canJoinAllApplications]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.worksWhenModal = true
        panel.contentView = NSHostingView(rootView: NotchRootView(model: model, notchSize: notchSize, services: services))
        panel.orderFrontRegardless()
        self.panel = panel

        model.onDidClose = { [weak panel] in
            panel?.makeFirstResponder(nil)
        }

        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak panel, weak model] _ in
            Task { @MainActor in
                panel?.makeFirstResponder(nil)
                model?.setEditingText(false)
            }
        }

        setupMouseTracking()
    }

    private func setupMouseTracking() {
        updateMouseTracking()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMouseTracking()
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.updateMouseTracking()
            return event
        }
    }

    private func updateMouseTracking() {
        let mouseLoc = NSEvent.mouseLocation
        let shapeSize = model.isOpen ? NotchGeometry.openSize : NotchGeometry.closedSize(notch: notchSize, showsIndicators: services.showsClosedIndicators)
        let shapeX = screen.frame.minX + (screen.frame.width - shapeSize.width) / 2
        let shapeY = screen.frame.maxY - shapeSize.height
        let shapeRect = NSRect(x: shapeX, y: shapeY, width: shapeSize.width, height: shapeSize.height)
        let paddedRect = shapeRect.insetBy(dx: -8, dy: -8)
        let inside = paddedRect.contains(mouseLoc)
        panel.ignoresMouseEvents = !inside
    }

    func close() {
        if let gm = globalMonitor {
            NSEvent.removeMonitor(gm)
            globalMonitor = nil
        }
        if let lm = localMonitor {
            NSEvent.removeMonitor(lm)
            localMonitor = nil
        }
        if let obs = resignKeyObserver {
            NotificationCenter.default.removeObserver(obs)
            resignKeyObserver = nil
        }
        panel.close()
    }

    deinit {
        if let gm = globalMonitor {
            NSEvent.removeMonitor(gm)
        }
        if let lm = localMonitor {
            NSEvent.removeMonitor(lm)
        }
        if let obs = resignKeyObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }
}
