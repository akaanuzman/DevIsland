import AppKit
import SwiftUI

@MainActor enum PanelSizing {
    /// Measure the very same visible SwiftUI tree at its destination width, before introducing a viewport.
    static func height<V: View>(of view: V, width: CGFloat, maximum: CGFloat) -> CGFloat {
        let host = NSHostingController(rootView: view.frame(width: width).fixedSize(horizontal: false, vertical: true))
        let natural = host.sizeThatFits(in: CGSize(width: width, height: 100_000)).height
        return min(maximum, ceil(natural))
    }
    static func host<V: View>(_ view: V) -> NSHostingView<V> {
        let host = NSHostingView(rootView: view)
        // The transition coordinator owns every pixel. No implicit min/max window constraints.
        host.sizingOptions = []
        return host
    }
}
