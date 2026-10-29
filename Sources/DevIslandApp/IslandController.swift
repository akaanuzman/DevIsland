import AppKit
import SwiftUI
import Combine
import DevIslandCore

extension NSScreen {
    var displayIdentifier: UInt32 { (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0 }
}
final class IslandPanel: NSPanel {
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
    init(model: AppModel) {
        self.model = model
        panel = IslandPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.escape = { [weak self] in self?.collapse() }
        panel.level = .statusBar; panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = true
        panel.hidesOnDeactivate = false; panel.isFloatingPanel = true; panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.contentView = PanelSizing.host(IslandView(model: model, presentation: presentation))
        panel.setAccessibilityLabel("Dev Island")
        presentation.hover = { [weak self] in self?.hover($0) }
        presentation.toggle = { [weak self] in self?.toggle() }
        presentation.collapse = { [weak self] in self?.collapse() }
        model.$ledger.receive(on: RunLoop.main).sink { [weak self] _ in self?.layout() }.store(in: &subscriptions)
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.layout() }
        }
    }
    private var display: NSScreen? {
        if model.preferences.displayID != 0, let chosen = NSScreen.screens.first(where: { $0.displayIdentifier == model.preferences.displayID }) { return chosen }
        return NSScreen.screens.first(where: { CGDisplayIsBuiltin($0.displayIdentifier) != 0 }) ?? NSScreen.main ?? NSScreen.screens.first
    }
    func layout() {
        guard let screen = display else { return }
        applyAppearance(model.preferences, to: panel)
        panel.collectionBehavior = model.preferences.showOverFullscreen ? [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary] : [.canJoinAllSpaces, .stationary]
        guard model.preferences.showsIsland else { frameTimer?.invalidate(); panel.orderOut(nil); presentation.visible = false; return }
        let top = max(36, screen.safeAreaInsets.top)
        let notch = screen.auxiliaryTopLeftArea.flatMap { left in screen.auxiliaryTopRightArea.map { max(0, $0.minX - left.maxX) } } ?? 0
        presentation.safeTop = top; presentation.notchWidth = notch
        let mode = presentation.mode
        let width = mode == .compact ? max(180, notch + 150) : min(max(460, notch + 180), screen.frame.width - 32)
        let maximum = max(0, min(520, screen.visibleFrame.height - top - 24))
        let bodyHeight: CGFloat
        switch mode {
        case .compact: bodyHeight = 0
        case .alert:
            bodyHeight = PanelSizing.height(of: IslandAlertBody(model: model, sessionID: presentation.sessionID, close: {}, showAll: {}).appTheme(model.preferences), width: width, maximum: maximum)
        case .expanded:
            bodyHeight = PanelSizing.height(of: SessionTrayView(model: model, close: {}).appTheme(model.preferences), width: width, maximum: maximum)
        }
        let geometry = IslandGeometry(width: width, height: min(screen.visibleFrame.height, top + bodyHeight), radius: mode == .compact ? 18 : 26, contentOpacity: mode == .compact ? 0 : 1)
        if model.sessions.isEmpty && mode == .compact { panel.orderOut(nil); presentation.visible = false; frameTimer?.invalidate(); return }
        let now = ProcessInfo.processInfo.systemUptime
        if !panel.isVisible {
            transition = IslandTransition(mode == .compact ? geometry : IslandGeometry(width: max(180, notch + 150), height: top, radius: 18))
            render(at: now); panel.orderFrontRegardless(); presentation.visible = true
        }
        if transition.retarget(geometry, at: now, reducedMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion) {
            startClock()
        } else if frameTimer?.isValid != true { render(at: now) }
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
        var geometry = transition.sample(at: now)
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
        presentation.geometry = geometry
        panel.setFrame(NSRect(x: screen.frame.midX - geometry.width / 2, y: screen.frame.maxY - geometry.height,
                              width: geometry.width, height: geometry.height), display: true)
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
        guard model.preferences.showsIsland, presentation.mode != .expanded else { return }
        if presentation.mode == .alert, let current = presentation.sessionID,
           let old = model.ledger.sessions[current], let new = model.ledger.sessions[id], old.state.priority < new.state.priority { return }
        presentation.sessionID = id; remaining = 8; changeMode(.alert); scheduleDismiss()
    }
    func toggle() { if presentation.mode == .expanded { collapse() } else { expand() } }
    func expand(focus: Bool = true) {
        guard model.preferences.showsIsland else { model.showSettings?(); return }
        hoverTask?.cancel(); dismissTask?.cancel(); closeAt = nil
        if focus { interaction.pin() }
        changeMode(.expanded); model.markCompletionsSeen()
        if focus { NSApp.activate(ignoringOtherApps: true); panel.makeKey() }
    }
    func collapse() {
        hoverTask?.cancel(); dismissTask?.cancel(); closeAt = nil; interaction.collapse()
        changeMode(.compact); panel.resignKey()
    }
    private func scheduleDismiss() {
        dismissTask?.cancel()
        guard presentation.mode == .alert, !interaction.hovered else { return }
        closeAt = Date().addingTimeInterval(remaining)
        dismissTask = Task { [weak self, remaining] in
            try? await Task.sleep(nanoseconds: UInt64(max(0.01, remaining) * 1_000_000_000))
            guard !Task.isCancelled, let self, self.presentation.mode == .alert else { return }; self.collapse()
        }
    }
    private func hover(_ inside: Bool) {
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
