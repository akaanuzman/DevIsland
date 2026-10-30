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
    private var interaction = IslandInteraction()
    private var remaining: TimeInterval = 8
    private var closeAt: Date?
    private var swapTime: TimeInterval?
    private var pendingBody: IslandMode?
    private var contentFadeStart: TimeInterval?
    private var currentAnchor: IslandAnchor?
    private var dragOrigin: IslandAnchor?
    private var dragPlacement: IslandPlacement?
    private var dragGeometry: IslandGeometry?
    private var deferredAlertID: String?
    private var dockedMouseMonitor: Any?
    private var cameraInputRect = CGRect.zero
    var windowFrame: CGRect { panel.frame }
    var windowLevel: NSWindow.Level { panel.level }
    var isDragging: Bool { interaction.dragging }
    init(model: AppModel, screens: (@MainActor () -> [IslandDisplay])? = nil) {
        self.model = model; self.screens = screens ?? { IslandDisplay.connected() }
        panel = IslandPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.allowsPhysicalTop = true; panel.animationBehavior = .none
        panel.escape = { [weak self] in self?.collapse() }
        panel.level = .statusBar; panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = true
        panel.hidesOnDeactivate = false; panel.isFloatingPanel = false; panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        let host = IslandHoverHostingView(rootView: IslandView(model: model, presentation: presentation))
        host.sizingOptions = []; host.hoverChanged = { [weak self] in self?.hover($0) }
        panel.acceptsMouseMovedEvents = true; panel.contentView = host
        panel.setAccessibilityLabel("Dev Island")
        presentation.hover = { [weak self] in self?.hover($0) }
        presentation.toggle = { [weak self] in self?.toggle() }
        presentation.collapse = { [weak self] in self?.collapse() }
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
        presentation.pinTitle = model.t("Üste sabitle", "Pin to top")
        applyAppearance(model.preferences, to: panel)
        panel.collectionBehavior = model.preferences.showOverFullscreen ? [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary] : [.canJoinAllSpaces, .stationary]
        guard model.preferences.showsIsland else { hidePanel(); return }
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
        if !interaction.dragging { presentation.expandsUpward = IslandLayout.opensUpward(anchor: anchor, visible: screen.visibleFrame, headerHeight: top) }
        if dragGeometry != nil { render(at: ProcessInfo.processInfo.systemUptime); return }
        let mode = presentation.mode
        let width = mode == .compact ? compactWidth : max(compactWidth, min(460, screen.visibleFrame.width - 16))
        let maximum = min(520, IslandLayout.bodyRoom(anchor: anchor, visible: screen.visibleFrame, headerHeight: top, upward: presentation.expandsUpward))
        let bodyHeight: CGFloat
        switch mode {
        case .compact: bodyHeight = 0
        case .alert:
            bodyHeight = PanelSizing.height(of: IslandAlertBody(model: model, sessionID: presentation.sessionID, close: {}, showAll: {}).appTheme(model.preferences), width: width, maximum: maximum)
        case .expanded:
            bodyHeight = PanelSizing.height(of: SessionTrayView(model: model, close: {}).appTheme(model.preferences), width: width, maximum: maximum)
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
            Task { @MainActor in self?.handleDockedExternalPointer(at: NSEvent.mouseLocation, clicked: clicked) }
        }
    }
    func handleDockedExternalPointer(at point: CGPoint, clicked: Bool) {
        guard presentation.visible, presentation.attachedToTop, !interaction.dragging else { return }
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
        if let swapTime, let pendingBody {
            if now < swapTime { geometry.contentOpacity *= max(0, (swapTime - now) / 0.08) }
            else {
                presentation.bodyMode = pendingBody; self.pendingBody = nil; self.swapTime = nil
                contentFadeStart = now
            }
        }
        if let start = contentFadeStart {
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
    func beginDrag() {
        guard !interaction.dragging, let anchor = currentAnchor else { return }
        dragOrigin = anchor; dragPlacement = model.preferences.islandPlacement
        dragGeometry = presentation.geometry; transition = IslandTransition(presentation.geometry)
        frameTimer?.invalidate(); frameTimer = nil; hoverTask?.cancel()
        if let closeAt { remaining = max(0.1, closeAt.timeIntervalSinceNow) }
        dismissTask?.cancel(); closeAt = nil; interaction.beginDrag()
    }
    func drag(by delta: CGPoint, at pointer: CGPoint? = nil) {
        guard interaction.dragging, let origin = dragOrigin else { return }
        guard let target = screens().first(where: { $0.frame.contains(pointer ?? NSEvent.mouseLocation) }) ?? display else { return }
        let anchor = IslandAnchor(centerX: origin.centerX + delta.x, headerTop: origin.headerTop + delta.y)
        dragPlacement = IslandLayout.placement(anchor: anchor, screen: target.frame, visible: target.visibleFrame, displayID: target.displayIdentifier, snap: false)
        layout()
    }
    func endDrag(cancelled: Bool = false) {
        guard interaction.dragging else { return }
        if !cancelled, let anchor = currentAnchor, let screen = display {
            model.preferences.islandPlacement = IslandLayout.placement(anchor: anchor, screen: screen.frame, visible: screen.visibleFrame, displayID: screen.displayIdentifier)
        }
        transition = IslandTransition(presentation.geometry)
        dragGeometry = nil; dragPlacement = nil; dragOrigin = nil
        interaction.endDrag(hovered: panel.frame.contains(NSEvent.mouseLocation))
        layout()
        if let id = deferredAlertID { deferredAlertID = nil; alert(id) }
        else if presentation.mode == .alert { scheduleDismiss() }
    }
    private func hidePanel() {
        updateDockedMouseMonitor(enabled: false)
        if interaction.dragging { interaction.endDrag(hovered: false) }
        dragGeometry = nil; dragPlacement = nil; dragOrigin = nil; deferredAlertID = nil
        frameTimer?.invalidate(); frameTimer = nil; dismissTask?.cancel(); hoverTask?.cancel(); closeAt = nil
        pendingBody = nil; swapTime = nil; contentFadeStart = nil
        presentation.mode = .compact; presentation.bodyMode = .compact; presentation.sessionID = nil
        presentation.visible = false; panel.orderOut(nil)
    }
    func stop() { hidePanel(); panel.close() }
    func resetPosition() {
        if interaction.dragging { endDrag(cancelled: true) }
        model.preferences.islandPlacement = .init(displayID: display?.displayIdentifier ?? 0)
        layout()
    }
    func pinToTop() {
        if interaction.dragging { endDrag(cancelled: true) }
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
        if interaction.dragging {
            if let previous = deferredAlertID, let old = model.ledger.sessions[previous], let next = model.ledger.sessions[id], old.state.priority < next.state.priority { return }
            deferredAlertID = id; return
        }
        guard model.preferences.showsIsland, presentation.mode != .expanded else { return }
        if presentation.mode == .alert, let current = presentation.sessionID,
           let old = model.ledger.sessions[current], let new = model.ledger.sessions[id], old.state.priority < new.state.priority { return }
        presentation.sessionID = id; remaining = 8; changeMode(.alert); scheduleDismiss()
    }
    func toggle() { guard !interaction.dragging else { return }; if presentation.mode == .expanded { collapse() } else { expand() } }
    func expand(focus: Bool = true) {
        guard !interaction.dragging else { return }
        guard model.preferences.showsIsland else { model.showSettings?(); return }
        hoverTask?.cancel(); dismissTask?.cancel(); closeAt = nil
        if focus { interaction.pin() }
        changeMode(.expanded); model.markCompletionsSeen()
        if focus { NSApp.activate(ignoringOtherApps: true); panel.makeKey() }
    }
    func collapse() {
        guard !interaction.dragging else { return }
        hoverTask?.cancel(); dismissTask?.cancel(); closeAt = nil; interaction.collapse()
        changeMode(.compact); panel.resignKey()
    }
    private func scheduleDismiss() {
        dismissTask?.cancel()
        guard presentation.mode == .alert, !interaction.hovered, !interaction.dragging else { return }
        closeAt = Date().addingTimeInterval(remaining)
        dismissTask = Task { [weak self, remaining] in
            try? await Task.sleep(nanoseconds: UInt64(max(0.01, remaining) * 1_000_000_000))
            guard !Task.isCancelled, let self, self.presentation.mode == .alert else { return }; self.collapse()
        }
    }
    private func hover(_ inside: Bool) {
        guard !interaction.dragging, inside != interaction.hovered else { return }
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
