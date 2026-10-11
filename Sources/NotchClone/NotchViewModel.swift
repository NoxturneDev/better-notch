import Foundation
import Observation

@MainActor
@Observable
final class NotchViewModel {
    var isOpen: Bool = false
    var isHovering: Bool = false
    var isDropTargeted: Bool = false
    var isEditingText: Bool = false
    var selectedTab: NotchTab = .home

    var onDidClose: (() -> Void)?

    private var transitionTask: Task<Void, Never>?

    func setHovering(_ hovering: Bool) {
        isHovering = hovering
        transitionTask?.cancel()

        if hovering {
            transitionTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000)
                if !Task.isCancelled {
                    isOpen = true
                }
            }
        } else {
            transitionTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                if !Task.isCancelled && !isDropTargeted && !isEditingText {
                    isOpen = false
                    onDidClose?()
                }
            }
        }
    }

    func setDropTargeted(_ targeted: Bool) {
        isDropTargeted = targeted
        if targeted {
            transitionTask?.cancel()
            isOpen = true
        } else if !isHovering {
            transitionTask?.cancel()
            transitionTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                if !Task.isCancelled && !isHovering && !isDropTargeted && !isEditingText {
                    isOpen = false
                    onDidClose?()
                }
            }
        }
    }

    func setEditingText(_ editing: Bool) {
        isEditingText = editing
        if editing {
            transitionTask?.cancel()
            isOpen = true
        } else if !isHovering {
            setHovering(false)
        }
    }
}
