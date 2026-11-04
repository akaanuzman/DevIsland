import AppKit
import SwiftUI

/// A real rectangular 32 pt target, including first clicks while another app has focus.
@MainActor final class IslandCloseControl: NSButton {
    static let targetSize: CGFloat = 32
    var closeAction: (() -> Void)?
    override var intrinsicContentSize: NSSize { NSSize(width: Self.targetSize, height: Self.targetSize) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame)
        title = ""; imagePosition = .imageOnly
        image = NSImage(systemSymbolName: "xmark", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .medium))
        bezelStyle = .circular; isBordered = true; showsBorderOnlyWhileMouseInside = true
        contentTintColor = .secondaryLabelColor; focusRingType = .default
        keyEquivalent = "\u{1b}"; keyEquivalentModifierMask = []
        target = self; action = #selector(closePressed)
    }
    required init?(coder: NSCoder) { nil }
    @objc private func closePressed() { closeAction?() }
}

private struct NativeIslandCloseButton: NSViewRepresentable {
    let label: String
    var action: () -> Void
    func makeNSView(context: Context) -> IslandCloseControl { IslandCloseControl(frame: .zero) }
    func updateNSView(_ view: IslandCloseControl, context: Context) {
        view.closeAction = action
        view.setAccessibilityLabel(label)
        view.toolTip = label + " (Esc)"
    }
}
struct IslandCloseButton: View {
    let label: String
    var action: () -> Void
    @Environment(\.snapshotPreview) private var snapshot
    var body: some View {
        Group {
            if snapshot {
                Image(systemName: "xmark").font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary).accessibilityLabel(label)
            } else { NativeIslandCloseButton(label: label, action: action) }
        }
        .frame(width: IslandCloseControl.targetSize, height: IslandCloseControl.targetSize)
        .fixedSize()
    }
}
