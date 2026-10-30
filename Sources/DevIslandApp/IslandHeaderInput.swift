import AppKit
import SwiftUI
import DevIslandCore

struct IslandHeaderInput: NSViewRepresentable {
    @ObservedObject var presentation: IslandPresentation
    let resetTitle: String
    var sessionHelp: String? = nil
    func makeNSView(context: Context) -> HeaderInputView {
        let view = HeaderInputView(); view.setAccessibilityElement(false); return view
    }
    func updateNSView(_ view: HeaderInputView, context: Context) {
        view.clicked = presentation.toggle; view.began = presentation.dragBegan
        view.changed = presentation.dragChanged; view.ended = presentation.dragEnded
        view.cancelled = presentation.dragCancelled; view.reset = presentation.resetPosition
        view.toolTip = sessionHelp
        view.resetTitle = resetTitle
        view.pinToTop = presentation.pinToTop
        view.configurePin(visible: !presentation.attachedToTop, title: presentation.pinTitle)
    }
}

final class HeaderInputView: NSView {
    var clicked: (() -> Void)?
    var began: (() -> Void)?
    var changed: ((CGPoint) -> Void)?
    var ended: (() -> Void)?
    var cancelled: (() -> Void)?
    var reset: (() -> Void)?
    var resetTitle = "Reset to top center"
    var pinToTop: (() -> Void)?
    private(set) var pinButton = NSButton()
    private var showsPin = false
    override init(frame: NSRect) {
        super.init(frame: frame)
        pinButton.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: nil)
        pinButton.imagePosition = .imageOnly; pinButton.isBordered = false; pinButton.controlSize = .small
        pinButton.contentTintColor = .labelColor; pinButton.target = self; pinButton.action = #selector(pinAction)
        pinButton.isHidden = true; addSubview(pinButton)
    }
    required init?(coder: NSCoder) { nil }
    func configurePin(visible: Bool, title: String) {
        showsPin = visible; pinButton.isHidden = !visible
        pinButton.toolTip = title; pinButton.setAccessibilityLabel(title)
        needsLayout = true; window?.invalidateCursorRects(for: self)
    }
    override func layout() {
        super.layout()
        pinButton.frame = CGRect(x: max(0, bounds.maxX - 40), y: (bounds.height - 24) / 2, width: 24, height: 24)
    }
    @objc private func pinAction() { pinToTop?() }
    private var gesture = IslandDragGesture()
    private var pressed = false
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() {
        if showsPin {
            addCursorRect(CGRect(x: 0, y: 0, width: max(0, pinButton.frame.minX), height: bounds.height), cursor: .openHand)
            addCursorRect(pinButton.frame, cursor: .pointingHand)
        } else { addCursorRect(bounds, cursor: .openHand) }
    }
    override func mouseDown(with event: NSEvent) { press(at: NSEvent.mouseLocation) }
    override func mouseDragged(with event: NSEvent) { move(to: NSEvent.mouseLocation) }
    override func mouseUp(with event: NSEvent) { release() }
    func press(at point: CGPoint) { pressed = true; gesture.press(at: point) }
    func move(to point: CGPoint) {
        let alreadyDragging = gesture.isDragging
        if gesture.move(to: point) {
            if !alreadyDragging { NSCursor.closedHand.set(); began?() }
            changed?(gesture.translation)
        }
    }
    func release() {
        guard pressed else { return }; pressed = false
        let dragged = gesture.release()
        NSCursor.openHand.set()
        if dragged { ended?() } else { clicked?() }
    }
    override func cancelOperation(_ sender: Any?) {
        if gesture.isDragging { pressed = false; gesture.cancel(); NSCursor.openHand.set(); cancelled?() }
    }
    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let item = NSMenuItem(title: resetTitle, action: #selector(resetAction), keyEquivalent: "")
        item.target = self; menu.addItem(item)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
    @objc private func resetAction() { reset?() }
}
