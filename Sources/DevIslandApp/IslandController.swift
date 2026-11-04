import AppKit
import SwiftUI
import Combine
import DevIslandCore

extension NSScreen {
    var displayIdentifier: UInt32 { (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0 }
}
final class IslandPanel: NSPanel {
    var allowsPhysicalTop = false
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        allowsPhysicalTop ? frameRect : super.constrainFrameRect(frameRect, to: screen)
    }
    var escape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { escape?() } else { super.keyDown(with: event) }
    }
}

@MainActor final class IslandController {
    let presentation = IslandPresentation()
    private let model: AppModel
    private let screens: @MainActor () -> [IslandDisplay]
    private let panel: IslandPanel
    private var subscriptions = Set<AnyCancellable>()
    private var transition = IslandTransition(.init(width: 180, height: 36, radius: 18))
    private var frameTimer: Timer?
    private var dismissTask: Task<Void, Never>?
    private var hoverTask: Task<Void, Never>?
    private var dismissalTask: Task<Void, Never>?
    private var userDismissalInFlight = false
    private let pointer: @MainActor () -> CGPoint
    private var interaction = IslandInteraction()
    private var remaining: TimeInterval = 8
    private var closeAt: Date?
    private var swapTime: TimeInterval?
    private var pendingBody: IslandMode?
    private var contentFadeStart: TimeInterval?
    private var currentAnchor: IslandAnchor?
    private var dragOrigin: IslandAnchor?
    private var pressPoint: CGPoint?
    private var gripFraction = CGPoint(x: 0.5, y: 0.5)
    private var pressTime: TimeInterval?
    private var hadKeyBeforePress = false
    private var bodyGrabOffset: CGPoint?
    private var originalPlacement: IslandPlacement?
    private var dragPlacement: IslandPlacement?
    private var dragGeometry: IslandGeometry?
    private var deferredAlertID: String?
    private var dockedMouseMonitor: Any?
    private var cameraInputRect = CGRect.zero
    var windowFrame: CGRect { panel.frame }
    var windowContentView: NSView? { panel.contentView }
    var windowLevel: NSWindow.Level { panel.level }
    var isDragging: Bool { interaction.dragging }
    init(model: AppModel, screens: (@MainActor () -> [IslandDisplay])? = nil, pointer: @escaping @MainActor () -> CGPoint = { NSEvent.mouseLocation }) {
        self.model = model; self.screens = screens ?? { IslandDisplay.connected() }; self.pointer = pointer
        panel = IslandPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isMovable = false; panel.isMovableByWindowBackground = false
        panel.allowsPhysicalTop = true; panel.animationBehavior = .none
        panel.escape = { [weak self] in
            guard let self else { return }
            if self.interaction.interacting { self.presentation.cancelHeaderInput?(); self.endDrag(cancelled: true) }
            else { self.dismiss() }
        }
        panel.level = .statusBar; panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = true
        panel.hidesOnDeactivate = false; panel.isFloatingPanel = false; panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        let host = IslandHoverHostingView(rootView: IslandView(model: model, presentation: presentation))
        host.sizingOptions = []; host.hoverChanged = { [weak self] in self?.hover($0) }
        panel.acceptsMouseMovedEvents = true; panel.contentView = host
        panel.setAccessibilityLabel("Dev Island")
        presentation.hover = { [weak self] in self?.hover($0) }
        presentation.toggle = { [weak self] in self?.toggle() }
        presentation.collapse = { [weak self] in self?.dismiss() }
        presentation.bodyPressed = { [weak self] in self?.beginPress(at: $0, fromBody: true) }
        presentation.detachFromTop = { [weak self] in self?.detachFromTop() }
        presentation.headerPressed = { [weak self] in self?.beginPress(at: $0) }
        presentation.headerReleased = { [weak self] in self?.endDrag() }
        presentation.dragBegan = { [weak self] in self?.beginDrag() }
        presentation.dragChanged = { [weak self] in self?.drag(by: $0) }
        presentation.dragEnded = { [weak self] in self?.endDrag() }
        presentation.dragCancelled = { [weak self] in self?.endDrag(cancelled: true) }
        presentation.resetPosition = { [weak self] in self?.resetPosition() }
        presentation.pinToTop = { [weak self] in self?.pinToTop() }
        model.resetIslandPosition = { [weak self] in self?.resetPosition() }
        model.$ledger.receive(on: RunLoop.main).sink { [weak self] _ in self?.layout() }.store(in: &subscriptions)
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.layout() }
        }
    }
    private var display: IslandDisplay? {
        let placement = dragPlacement ?? model.preferences.islandPlacement
        if placement.displayID != 0, let chosen = screens().first(where: { $0.displayIdentifier == placement.displayID }) { return chosen }
        if model.preferences.displayID != 0, let chosen = screens().first(where: { $0.displayIdentifier == model.preferences.displayID }) { return chosen }
        return screens().first(where: { $0.isBuiltIn }) ?? screens().first(where: { $0.isMain }) ?? screens().first
    }
    func layout() {
        guard let screen = display else { hidePanel(); return }
        if interaction.interacting, let placement = dragPlacement, placement.displayID != 0, !screens().contains(where: { $0.displayIdentifier == placement.displayID }) {
            endDrag(cancelled: true); return
        }
        presentation.pinTitle = model.t("Üste sabitle", "Pin to top")
        applyAppearance(model.preferences, to: panel)
        panel.collectionBehavior = model.preferences.showOverFullscreen ? [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary] : [.canJoinAllSpaces, .stationary]
        guard model.preferences.showsIsland else { hidePanel(); return }
        if interaction.interacting, dragGeometry != nil {
            currentAnchor = IslandLayout.anchor(placement: dragPlacement ?? model.preferences.islandPlacement,
                                               screen: screen.frame, visible: screen.visibleFrame,
                                               header: CGSize(width: presentation.headerWidth, height: presentation.safeTop))
            render(at: ProcessInfo.processInfo.systemUptime); return
        }
        let placement = dragPlacement ?? model.preferences.islandPlacement
        let attached = !placement.isCustom
        // Physical camera pixels cannot be a hit target; expose a small real strip underneath.
        let top = attached ? max(36, screen.topInset + (screen.notchWidth > 0 ? 6 : 0)) : 36
        panel.level = attached ? NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1) : .floating
        cameraInputRect = attached && screen.notchWidth > 0 ? CGRect(x: screen.frame.midX - screen.notchWidth / 2, y: screen.frame.maxY - screen.topInset, width: screen.notchWidth, height: screen.topInset) : .zero
        if !attached { updateDockedMouseMonitor(enabled: false) }
        let notch = attached ? screen.notchWidth : 0
        let compactWidth = IslandHeaderLayout.width(notch: notch, available: screen.frame.width)
        presentation.safeTop = top; presentation.notchWidth = notch; presentation.headerWidth = compactWidth
        let anchor = IslandLayout.anchor(placement: placement, screen: screen.frame, visible: screen.visibleFrame, header: CGSize(width: compactWidth, height: top))
        currentAnchor = anchor; presentation.attachedToTop = anchor.attachedToTop; panel.hasShadow = !anchor.attachedToTop
        if !interaction.interacting { presentation.expandsUpward = IslandLayout.opensUpward(anchor: anchor, visible: screen.visibleFrame, headerHeight: top) }
        if dragGeometry != nil { render(at: ProcessInfo.processInfo.systemUptime); return }
        let mode = presentation.mode
        let width = mode == .compact ? compactWidth : max(compactWidth, min(460, screen.visibleFrame.width - 16))
        let maximum = min(520, IslandLayout.bodyRoom(anchor: anchor, visible: screen.visibleFrame, headerHeight: top, upward: presentation.expandsUpward))
        let bodyHeight: CGFloat
        switch mode {
        case .compact: bodyHeight = 0
        case .alert:
            bodyHeight = PanelSizing.height(of: IslandAlertBody(model: model, sessionID: presentation.sessionID, island: presentation, close: {}, showAll: {}).appTheme(model.preferences), width: width, maximum: maximum)
        case .expanded:
            bodyHeight = PanelSizing.height(of: SessionTrayView(model: model, island: presentation, close: {}).appTheme(model.preferences), width: width, maximum: maximum)
        }
        let geometry = IslandGeometry(width: width, height: top + bodyHeight, radius: mode == .compact ? 18 : 26, contentOpacity: mode == .compact ? 0 : 1)
        if model.sessions.isEmpty && mode == .compact { hidePanel(); return }
        let now = ProcessInfo.processInfo.systemUptime
        if !panel.isVisible {
            transition = IslandTransition(mode == .compact ? geometry : IslandGeometry(width: compactWidth, height: top, radius: 18))
            render(at: now); panel.orderFrontRegardless(); presentation.visible = true
        }
        if transition.retarget(geometry, at: now, reducedMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion) {
            startClock()
        } else if frameTimer?.isValid != true { render(at: now) }
        updateDockedMouseMonitor(enabled: attached && presentation.visible)
    }
    private func updateDockedMouseMonitor(enabled: Bool) {
        if !enabled {
            if let dockedMouseMonitor { NSEvent.removeMonitor(dockedMouseMonitor); self.dockedMouseMonitor = nil }
            return
        }
        guard dockedMouseMonitor == nil else { return }
        // Mouse-only fallback for the camera/menu-bar area; no keyboard observation or event suppression.
        dockedMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown]) { [weak self] event in
            let clicked = event.type == .leftMouseDown
            let point = NSEvent.mouseLocation
            Task { @MainActor in self?.handleDockedExternalPointer(at: point, clicked: clicked) }
        }
    }
    func handleDockedExternalPointer(at point: CGPoint, clicked: Bool) {
        guard presentation.visible, presentation.attachedToTop, !interaction.interacting else { return }
        if clicked {
            // Foreign clicks in menu/status items outside the camera are never treated as island clicks.
            if cameraInputRect.contains(point) { toggle() }
        } else { hover(panel.frame.contains(point)) }
    }
    private func startClock() {
        guard frameTimer?.isValid != true else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in Task { @MainActor in self?.frame() } }
        frameTimer = timer; RunLoop.main.add(timer, forMode: .common)
    }
    private func frame() {
        let now = ProcessInfo.processInfo.systemUptime
        render(at: now)
        if transition.isFinished(at: now) && pendingBody == nil && contentFadeStart == nil {
            frameTimer?.invalidate(); frameTimer = nil
            if presentation.mode == .compact { presentation.bodyMode = .compact; presentation.sessionID = nil }
        }
    }
    private func render(at now: TimeInterval) {
        guard let screen = display else { return }
        var geometry = dragGeometry ?? transition.sample(at: now)
        if !interaction.interacting, let swapTime, let pendingBody {
            if now < swapTime { geometry.contentOpacity *= max(0, (swapTime - now) / 0.08) }
            else {
                presentation.bodyMode = pendingBody; self.pendingBody = nil; self.swapTime = nil
                contentFadeStart = now
            }
        }
        if !interaction.interacting, let start = contentFadeStart {
            geometry.contentOpacity *= min(1, max(0, (now - start) / 0.13))
            if now - start >= 0.13 { contentFadeStart = nil }
        }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion && !transition.isFinished(at: now) {
            geometry.width = transition.target.width; geometry.height = transition.target.height
        }
        if dragGeometry != nil, let anchor = currentAnchor {
            geometry.width = min(geometry.width, max(1, screen.visibleFrame.width - 16))
            geometry.height = min(geometry.height, presentation.safeTop + IslandLayout.bodyRoom(anchor: anchor, visible: screen.visibleFrame, headerHeight: presentation.safeTop, upward: presentation.expandsUpward))
        }
        guard let anchor = currentAnchor else { return }
        let frame = IslandLayout.frame(anchor: anchor, size: CGSize(width: geometry.width, height: geometry.height), headerHeight: presentation.safeTop,
                                       visible: anchor.attachedToTop ? screen.frame : screen.visibleFrame, upward: presentation.expandsUpward)
        presentation.geometry = geometry
        presentation.headerOffset = anchor.centerX - frame.minX - presentation.headerWidth / 2
        panel.setFrame(frame, display: true)
    }
    func beginPress(at point: CGPoint, fromBody: Bool = false) {
        guard !interaction.interacting, let anchor = currentAnchor else { return }
        cancelUserDismissal()
        pressPoint = point; pressTime = ProcessInfo.processInfo.systemUptime
        hadKeyBeforePress = panel.isKeyWindow; panel.makeKey()
        bodyGrabOffset = fromBody ? CGPoint(x: point.x - panel.frame.minX,
            y: presentation.expandsUpward ? point.y - anchor.headerTop : anchor.headerTop - presentation.safeTop - point.y) : nil
        originalPlacement = model.preferences.islandPlacement
        dragOrigin = anchor; dragPlacement = originalPlacement
        let width = max(1, presentation.headerWidth), height = max(1, presentation.safeTop)
        gripFraction = CGPoint(x: min(1, max(0, (point.x - anchor.centerX + width / 2) / width)),
                               y: min(1, max(0, (anchor.headerTop - point.y) / height)))
        dragGeometry = presentation.geometry; transition = IslandTransition(presentation.geometry)
        frameTimer?.invalidate(); frameTimer = nil; hoverTask?.cancel()
        if let closeAt { remaining = max(0.1, closeAt.timeIntervalSinceNow) }
        dismissTask?.cancel(); closeAt = nil; interaction.press()
    }
    func beginDrag() {
        if !interaction.pressed, let anchor = currentAnchor {
            beginPress(at: CGPoint(x: anchor.centerX, y: anchor.headerTop - presentation.safeTop / 2))
        }
        guard interaction.pressed, !interaction.dragging else { return }
        interaction.beginDrag()
    }
    func drag(by delta: CGPoint, at pointer: CGPoint? = nil) {
        guard interaction.dragging, let start = pressPoint else { return }
        // The injected point selects a display in tests; the gesture's global delta owns movement.
        let point = CGPoint(x: start.x + delta.x, y: start.y + delta.y)
        guard let target = screens().first(where: { $0.frame.contains(pointer ?? point) }) ?? display else { return }
        let width = IslandHeaderLayout.width(notch: 0, available: target.frame.width)
        let oldHeader = presentation.safeTop
        presentation.headerWidth = width; presentation.safeTop = 36; presentation.notchWidth = 0
        presentation.attachedToTop = false; panel.level = .floating; panel.hasShadow = true
        updateDockedMouseMonitor(enabled: false); cameraInputRect = .zero
        if var geometry = dragGeometry {
            if presentation.mode == .compact { geometry.width = width }
            geometry.height = max(36, geometry.height - oldHeader + 36)
            dragGeometry = geometry
        }
        let raw: IslandAnchor
        if let offset = bodyGrabOffset {
            // Keep the exact body point, not a clamped header fraction, under the pointer.
            raw = IslandAnchor(centerX: point.x - offset.x + (dragGeometry?.width ?? width) / 2,
                               headerTop: presentation.expandsUpward ? point.y - offset.y : point.y + 36 + offset.y)
        } else {
            raw = IslandAnchor(centerX: point.x - (gripFraction.x - 0.5) * width,
                               headerTop: point.y + gripFraction.y * 36)
        }
        dragPlacement = IslandLayout.placement(anchor: raw, screen: target.frame, visible: target.visibleFrame,
                                              displayID: target.displayIdentifier, snap: false)
        currentAnchor = IslandLayout.anchor(placement: dragPlacement!, screen: target.frame, visible: target.visibleFrame,
                                           header: CGSize(width: width, height: 36))
        render(at: ProcessInfo.processInfo.systemUptime)
    }
    func endDrag(cancelled: Bool = false) {
        guard interaction.interacting else { return }
        let wasDragging = interaction.dragging
        let saved: IslandPlacement?
        if !cancelled, wasDragging, let anchor = currentAnchor, let screen = display {
            saved = IslandLayout.placement(anchor: anchor, screen: screen.frame, visible: screen.visibleFrame, displayID: screen.displayIdentifier)
        } else { saved = originalPlacement }
        if let pressTime {
            let elapsed = ProcessInfo.processInfo.systemUptime - pressTime
            if let swapTime { self.swapTime = swapTime + elapsed }
            if let contentFadeStart { self.contentFadeStart = contentFadeStart + elapsed }
        }
        transition = IslandTransition(presentation.geometry)
        dragGeometry = nil; dragPlacement = nil; dragOrigin = nil; pressPoint = nil; pressTime = nil; originalPlacement = nil; bodyGrabOffset = nil
        interaction.endDrag(hovered: false)
        if !hadKeyBeforePress { panel.resignKey() }
        if let saved, model.preferences.islandPlacement != saved { model.preferences.islandPlacement = saved }
        layout(); render(at: ProcessInfo.processInfo.systemUptime)
        // Snapping can move the final header away from the release point.
        interaction.endDrag(hovered: panel.frame.contains(pointer()))
        if let id = deferredAlertID { deferredAlertID = nil; alert(id) }
        else if presentation.mode == .alert { scheduleDismiss() }
    }
    private func hidePanel() {
        cancelUserDismissal()
        updateDockedMouseMonitor(enabled: false)
        if interaction.interacting { interaction.endDrag(hovered: false) }
        pressPoint = nil; pressTime = nil; originalPlacement = nil; bodyGrabOffset = nil
        presentation.cancelHeaderInput?()
        dragGeometry = nil; dragPlacement = nil; dragOrigin = nil; deferredAlertID = nil
        frameTimer?.invalidate(); frameTimer = nil; dismissTask?.cancel(); hoverTask?.cancel(); closeAt = nil
        pendingBody = nil; swapTime = nil; contentFadeStart = nil
        presentation.mode = .compact; presentation.bodyMode = .compact; presentation.sessionID = nil
        presentation.visible = false; panel.orderOut(nil)
    }
    func stop() { hidePanel(); panel.close() }
    func resetPosition() {
        if interaction.interacting { presentation.cancelHeaderInput?(); endDrag(cancelled: true) }
        model.preferences.islandPlacement = .init(displayID: display?.displayIdentifier ?? 0)
        layout()
    }
    func detachFromTop() {
        guard !interaction.interacting, presentation.attachedToTop, let screen = display, let anchor = currentAnchor else { return }
        let floating = IslandAnchor(centerX: anchor.centerX, headerTop: screen.visibleFrame.maxY - 16)
        model.preferences.islandPlacement = IslandLayout.placement(anchor: floating, screen: screen.frame,
            visible: screen.visibleFrame, displayID: screen.displayIdentifier, snap: false)
        layout(); render(at: ProcessInfo.processInfo.systemUptime)
    }
    func pinToTop() {
        if interaction.interacting { presentation.cancelHeaderInput?(); endDrag(cancelled: true) }
        collapse()
        interaction.resetForDock()
        resetPosition()
    }
    private func changeMode(_ mode: IslandMode) {
        guard presentation.mode != mode else { layout(); return }
        if mode != .compact {
            if presentation.bodyMode != .compact && presentation.bodyMode != mode {
                pendingBody = mode; swapTime = ProcessInfo.processInfo.systemUptime + 0.08
            } else { presentation.bodyMode = mode; pendingBody = nil; swapTime = nil; contentFadeStart = nil }
        } else { pendingBody = nil; swapTime = nil; contentFadeStart = nil }
        presentation.mode = mode; layout()
    }
    func alert(_ id: String) {
        if interaction.interacting {
            if let previous = deferredAlertID, let old = model.ledger.sessions[previous], let next = model.ledger.sessions[id], old.state.priority < next.state.priority { return }
            deferredAlertID = id; return
        }
        guard model.preferences.showsIsland, presentation.mode != .expanded else { return }
        if presentation.mode == .alert, let current = presentation.sessionID,
           let old = model.ledger.sessions[current], let new = model.ledger.sessions[id], old.state.priority < new.state.priority { return }
        cancelUserDismissal()
        presentation.sessionID = id; remaining = 8; changeMode(.alert); scheduleDismiss()
    }
    func toggle() { guard !interaction.interacting else { return }; if presentation.mode == .expanded { dismiss() } else { expand() } }
    func expand(focus: Bool = true) {
        guard !interaction.interacting else { return }
        guard model.preferences.showsIsland else { model.showSettings?(); return }
        cancelUserDismissal()
        hoverTask?.cancel(); dismissTask?.cancel(); closeAt = nil
        if focus { interaction.pin() }
        changeMode(.expanded); model.markCompletionsSeen()
        if focus { NSApp.activate(ignoringOtherApps: true); panel.makeKey() }
    }
    func collapse() {
        guard !interaction.interacting else { return }
        cancelUserDismissal()
        hoverTask?.cancel(); dismissTask?.cancel(); closeAt = nil; interaction.collapse()
        changeMode(.compact); panel.resignKey()
    }
    /// Explicit close/Escape: ignore resize-generated hover events until the closing frame settles.
    func dismiss() {
        guard !interaction.interacting, presentation.mode != .compact else { return }
        collapse()
        interaction.dismiss(); userDismissalInFlight = true
        let ticket = interaction.generation
        let delay = transition.duration + 0.06
        dismissalTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self, self.presentation.mode == .compact, self.interaction.generation == ticket else { return }
            self.userDismissalInFlight = false
            self.interaction.finishDismissal(hovered: self.panel.frame.contains(self.pointer()))
            self.dismissalTask = nil
        }
    }
    private func cancelUserDismissal() {
        dismissalTask?.cancel(); dismissalTask = nil; userDismissalInFlight = false
        interaction.resumeHover()
    }
    private func scheduleDismiss() {
        dismissTask?.cancel()
        guard presentation.mode == .alert, !interaction.hovered, !interaction.interacting else { return }
        closeAt = Date().addingTimeInterval(remaining)
        dismissTask = Task { [weak self, remaining] in
            try? await Task.sleep(nanoseconds: UInt64(max(0.01, remaining) * 1_000_000_000))
            guard !Task.isCancelled, let self, self.presentation.mode == .alert else { return }; self.collapse()
        }
    }
    private func hover(_ inside: Bool) {
        guard !userDismissalInFlight, !interaction.interacting, inside != interaction.hovered else { return }
        hoverTask?.cancel()
        if inside {
            let ticket = interaction.enter()
            if presentation.mode == .alert {
                if let closeAt { remaining = max(0.1, closeAt.timeIntervalSinceNow) }
                dismissTask?.cancel(); closeAt = nil
            } else if presentation.mode == .compact {
                hoverTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 120_000_000)
                    guard !Task.isCancelled, let self, self.interaction.permits(ticket, opening: true) else { return }; self.expand(focus: false)
                }
            }
        } else {
            let ticket = interaction.leave()
            if presentation.mode == .alert { scheduleDismiss() }
            else if presentation.mode == .expanded && !interaction.pinned {
                hoverTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    guard !Task.isCancelled, let self, self.interaction.permits(ticket, opening: false) else { return }; self.collapse()
                }
            }
        }
    }
}
