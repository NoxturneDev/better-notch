import AppKit
import Darwin
import Dispatch

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let services = AppServices()
    private var controllers: [NotchWindowController] = []
    private var statusItemController: StatusItemController?
    private var sigtermSource: (any DispatchSourceSignal)?
    private var sigintSource: (any DispatchSourceSignal)?

    override init() {
        super.init()
        setupSignalHandlers()
    }

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
        services.nowPlaying.stop()
        services.notes.flush()
    }

    private func setupSignalHandlers() {
        _ = signal(SIGTERM, SIG_IGN)
        _ = signal(SIGINT, SIG_IGN)

        let termSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        termSource.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.handleTerminationSignal(SIGTERM)
            }
        }
        termSource.resume()
        sigtermSource = termSource

        let intSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        intSource.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.handleTerminationSignal(SIGINT)
            }
        }
        intSource.resume()
        sigintSource = intSource
    }

    private func handleTerminationSignal(_ sig: Int32) {
        sigtermSource?.cancel()
        sigintSource?.cancel()
        sigtermSource = nil
        sigintSource = nil
        services.nowPlaying.stop()
        services.notes.flush()
        NSApp.terminate(nil)
        exit(0)
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
