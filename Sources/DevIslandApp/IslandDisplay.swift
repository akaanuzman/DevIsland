import AppKit

/// Display geometry can be supplied to exercise the real NSPanel without a WindowServer screen.
struct IslandDisplay {
    var displayIdentifier: UInt32
    var frame: CGRect
    var visibleFrame: CGRect
    var topInset: CGFloat = 0
    var notchWidth: CGFloat = 0
    var isBuiltIn = false
    var isMain = false
    @MainActor static func connected() -> [IslandDisplay] {
        NSScreen.screens.map { screen in
            let notch = screen.auxiliaryTopLeftArea.flatMap { left in screen.auxiliaryTopRightArea.map { max(0, $0.minX - left.maxX) } } ?? 0
            return .init(displayIdentifier: screen.displayIdentifier, frame: screen.frame, visibleFrame: screen.visibleFrame,
                         topInset: screen.safeAreaInsets.top, notchWidth: notch,
                         isBuiltIn: CGDisplayIsBuiltin(screen.displayIdentifier) != 0, isMain: screen == NSScreen.main)
        }
    }
}
