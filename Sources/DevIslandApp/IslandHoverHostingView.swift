import AppKit
import SwiftUI

/// Track the entire panel even while another application has keyboard focus.
final class IslandHoverHostingView: PanelHostingView<IslandView> {
    var hoverChanged: ((Bool) -> Void)?
    private var islandArea: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        // inVisibleRect follows resizing itself; keep the same area during the island animation.
        if let islandArea, trackingAreas.contains(where: { $0 === islandArea }) { return }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect, .enabledDuringMouseDrag], owner: self, userInfo: nil)
        addTrackingArea(area); islandArea = area
    }
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        hoverChanged?(bounds.contains(convert(event.locationInWindow, from: nil)))
    }
    override func mouseEntered(with event: NSEvent) {
        if event.trackingArea === islandArea { hoverChanged?(true) }
        else { super.mouseEntered(with: event) }
    }
    override func mouseExited(with event: NSEvent) {
        if event.trackingArea === islandArea { hoverChanged?(false) }
        else { super.mouseExited(with: event) }
    }
}
