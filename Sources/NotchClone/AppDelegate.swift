import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let services = AppServices()
    private var controllers: [NotchWindowController] = []
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupControllers()
        statusItemController = StatusItemController(services: services)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        services.notes.flush()
    }

    @objc private func screenParametersChanged() {
        setupControllers()
    }

    private func setupControllers() {
        for controller in controllers {
            controller.close()
        }
        controllers.removeAll()

        var hasNotch = false
        for screen in NSScreen.screens {
            if let notchSize = NotchGeometry.notchSize(for: screen) {
                hasNotch = true
                let controller = NotchWindowController(screen: screen, notchSize: notchSize, services: services)
                controllers.append(controller)
            }
        }

        if !hasNotch {
            NSLog("NotchClone: No screen with a notch detected.")
        }
    }
}
