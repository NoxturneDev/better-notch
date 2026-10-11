import AppKit

enum NotchGeometry {
    static let windowSize = CGSize(width: 720, height: 280)
    static let openSize = CGSize(width: 600, height: 210)
    static let indicatorWidth: CGFloat = 52

    static func closedSize(notch: CGSize, showsIndicators: Bool) -> CGSize {
        CGSize(width: notch.width + (showsIndicators ? indicatorWidth * 2 : 0), height: notch.height)
    }

    static func notchSize(for screen: NSScreen) -> CGSize? {
        let top = screen.safeAreaInsets.top
        guard top > 0,
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else { return nil }
        return CGSize(width: screen.frame.width - left.width - right.width, height: top)
    }
}
