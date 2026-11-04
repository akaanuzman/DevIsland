import AppKit
import SwiftUI
import DevIslandCore

@MainActor enum IslandGrip {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 10, height: 14), flipped: false) { _ in
            NSColor.labelColor.setFill()
            for x in [1.0, 7.0] {
                for y in [1.0, 6.0, 11.0] { NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 2, height: 2)).fill() }
            }
            return true
        }
        image.isTemplate = true
        return image
    }()
}

struct IslandHeaderInput: NSViewRepresentable {
    @ObservedObject var presentation: IslandPresentation
    let resetTitle: String
    let dragTitle: String
    var sessionHelp: String? = nil
    var bodyDrag = false
    func makeNSView(context: Context) -> HeaderInputView {
        let view = HeaderInputView(); view.setAccessibilityElement(false); return view
    }
    func updateNSView(_ view: HeaderInputView, context: Context) {
        view.pressedAction = { [weak view, weak presentation] point in
            // Only the input which actually owns mouse-down may cancel this gesture.
            presentation?.cancelHeaderInput = { [weak view] in view?.cancelGesture() }
            if bodyDrag { presentation?.bodyPressed?(point) }
            else { presentation?.headerPressed?(point) }
        }
        view.releasedAction = presentation.headerReleased
        view.clicked = bodyDrag ? presentation.detachFromTop : presentation.toggle; view.began = presentation.dragBegan
        view.changed = presentation.dragChanged; view.ended = presentation.dragEnded
        view.cancelled = presentation.dragCancelled; view.reset = presentation.resetPosition
        view.toolTip = [sessionHelp, dragTitle].compactMap { $0 }.joined(separator: " · ")
        view.grip.toolTip = dragTitle
        view.resetTitle = resetTitle
        view.pinToTop = presentation.pinToTop
        view.configurePin(visible: !bodyDrag && !presentation.attachedToTop, title: presentation.pinTitle)
        view.grip.isHidden = bodyDrag
    }
}

final class HeaderInputView: NSView {
    var pressedAction: ((CGPoint) -> Void)?
    var releasedAction: (() -> Void)?
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
    let grip = NSImageView()
    override init(frame: NSRect) {
        super.init(frame: frame)
        pinButton.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: nil)
        pinButton.imagePosition = .imageOnly; pinButton.isBordered = false; pinButton.controlSize = .small
        pinButton.contentTintColor = .labelColor; pinButton.target = self; pinButton.action = #selector(pinAction)
        pinButton.isHidden = true; addSubview(pinButton)
        grip.image = IslandGrip.image
        grip.contentTintColor = .secondaryLabelColor; grip.imageScaling = .scaleProportionallyDown
        grip.setAccessibilityElement(false); addSubview(grip)
    }
    required init?(coder: NSCoder) { nil }
    func configurePin(visible: Bool, title: String) {
        showsPin = visible; pinButton.isHidden = !visible
        pinButton.toolTip = title; pinButton.setAccessibilityLabel(title)
        needsLayout = true; window?.invalidateCursorRects(for: self)
    }
    override func layout() {
        super.layout()
        grip.frame = CGRect(x: max(0, bounds.width - (showsPin ? 118 : 90)), y: (bounds.height - 24) / 2, width: 24, height: 24)
        pinButton.frame = CGRect(x: max(0, bounds.maxX - 40), y: (bounds.height - 24) / 2, width: 24, height: 24)
    }
    @objc private func pinAction() { pinToTop?() }
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === grip ? self : hit
    }
    private var gesture = IslandDragGesture()
    private var pressed = false
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() {
        if showsPin {
            addCursorRect(CGRect(x: 0, y: 0, width: max(0, pinButton.frame.minX), height: bounds.height), cursor: .openHand)
            addCursorRect(pinButton.frame, cursor: .pointingHand)
        } else { addCursorRect(bounds, cursor: .openHand) }
    }
    private func screenPoint(_ event: NSEvent) -> CGPoint {
        window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
    }
    override var mouseDownCanMoveWindow: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self); press(at: screenPoint(event)) }
    override func mouseDragged(with event: NSEvent) { move(to: screenPoint(event)) }
    override func mouseUp(with event: NSEvent) { release() }
    func press(at point: CGPoint) { pressed = true; gesture.press(at: point); pressedAction?(point) }
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
        if dragged { ended?() } else { releasedAction?(); clicked?() }
    }
    override func cancelOperation(_ sender: Any?) {
        cancelGesture()
    }
    func cancelGesture() {
        guard pressed else { return }
        pressed = false; gesture.cancel(); NSCursor.openHand.set(); cancelled?()
    }
    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let item = NSMenuItem(title: resetTitle, action: #selector(resetAction), keyEquivalent: "")
        item.target = self; menu.addItem(item)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
    @objc private func resetAction() { reset?() }
}
