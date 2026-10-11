import AppKit
import Foundation
import Observation
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let services: AppServices
    private let statusItem: NSStatusItem
    private let popover: NSPopover

    init(services: AppServices) {
        self.services = services
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        super.init()

        setupStatusItem()
        setupPopover()
        observeWaitingCount()
    }

    private func setupStatusItem() {
        guard let button = statusItem.button else { return }
        if let image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "Agents") {
            image.isTemplate = true
            button.image = image
        }
        button.imagePosition = .imageLeft
        button.target = self
        button.action = #selector(handleStatusItemClick)
        updateTitle(count: services.herdr.waitingCount)
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 560)
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.delegate = self

        let view = AgentsPopoverView(services: services) { [weak self] _ in
            self?.popover.performClose(nil)
        }
        popover.contentViewController = NSHostingController(rootView: view)
    }

    private func updateTitle(count: Int) {
        guard let button = statusItem.button else { return }
        button.title = count > 0 ? " \(count)" : ""
    }

    private func observeWaitingCount() {
        withObservationTracking {
            let count = services.herdr.waitingCount
            updateTitle(count: count)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeWaitingCount()
            }
        }
    }

    @objc private func handleStatusItemClick() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - NSPopoverDelegate

    nonisolated func popoverWillShow(_ notification: Notification) {
        Task { @MainActor in
            services.popoverVisible = true
            services.updateAgentsActivity()
        }
    }

    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor in
            services.popoverVisible = false
            services.updateAgentsActivity()
        }
    }
}
