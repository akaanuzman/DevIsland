import XCTest
import AppKit
import DevIslandCore
@testable import DevIslandApp

final class IslandDragTests: XCTestCase {
    let screen = IslandDisplay(displayIdentifier: 987, frame: CGRect(x: 0, y: 0, width: 1200, height: 900), visibleFrame: CGRect(x: 0, y: 24, width: 1200, height: 842), topInset: 38, notchWidth: 190, isBuiltIn: true)

    @MainActor func testNativeHeaderRoutesClickAndDragToSeparateActions() {
        let view = HeaderInputView()
        var clicks = 0, begins = 0, ends = 0, moves = 0, cancels = 0
        view.clicked = { clicks += 1 }; view.began = { begins += 1 }; view.changed = { _ in moves += 1 }
        view.ended = { ends += 1 }; view.cancelled = { cancels += 1 }
        view.press(at: .zero); view.move(to: CGPoint(x: 1, y: 1)); view.release()
        XCTAssertEqual(clicks, 1); XCTAssertEqual(begins, 0)
        view.press(at: .zero); view.move(to: CGPoint(x: 10, y: 0)); view.move(to: CGPoint(x: 20, y: 5)); view.release()
        XCTAssertEqual(clicks, 1); XCTAssertEqual(begins, 1); XCTAssertEqual(moves, 2); XCTAssertEqual(ends, 1)
        view.press(at: .zero); view.move(to: CGPoint(x: 10, y: 0)); view.cancelOperation(nil)
        view.release(); XCTAssertEqual(cancels, 1); XCTAssertEqual(clicks, 1)
    }
    @MainActor func testRealPanelCanReachPhysicalTopAboveVisibleFrame() throws {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { throw XCTSkip("WindowServer exposes no physical NSScreen in this environment") }
        let panel = IslandPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false; panel.allowsPhysicalTop = true
        defer { panel.close() }
        let desired = CGRect(x: screen.frame.midX - 90, y: screen.frame.maxY - 36, width: 180, height: 36)
        XCTAssertEqual(panel.constrainFrameRect(desired, to: screen), desired)
        panel.setFrame(desired, display: true)
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        XCTAssertEqual(panel.frame.maxY, screen.frame.maxY, accuracy: 0.01)
    }
    @MainActor func testControllerSavesRestoresAndResetsDraggedHeader() throws {
        let m = LayoutTests().model(sessions: 1)
        m.preferences.displayID = screen.displayIdentifier
        let first = IslandController(model: m, screens: { [self] in [screen] }); first.layout()
        XCTAssertEqual(first.windowFrame.maxY, screen.frame.maxY, accuracy: 0.01)
        first.beginDrag()
        let destination = CGPoint(x: screen.visibleFrame.minX + 200, y: screen.visibleFrame.minY + 80)
        first.drag(by: CGPoint(x: destination.x - first.windowFrame.midX, y: destination.y - first.windowFrame.maxY), at: destination)
        XCTAssertTrue(first.isDragging); XCTAssertTrue(screen.visibleFrame.contains(first.windowFrame))
        first.endDrag(); RunLoop.main.run(until: Date().addingTimeInterval(0.35)); XCTAssertTrue(m.preferences.islandPlacement.isCustom)
        let dropped = first.windowFrame; first.stop()
        let restored = IslandController(model: m, screens: { [self] in [screen] }); restored.layout(); defer { restored.stop() }
        XCTAssertEqual(restored.windowFrame, dropped)
        restored.expand(focus: false)
        RunLoop.main.run(until: Date().addingTimeInterval(0.45))
        XCTAssertTrue(restored.presentation.expandsUpward)
        XCTAssertEqual(restored.windowFrame.minY, dropped.minY, accuracy: 0.01)
        XCTAssertTrue(screen.visibleFrame.contains(restored.windowFrame))
        restored.resetPosition()
        RunLoop.main.run(until: Date().addingTimeInterval(0.45))
        XCTAssertFalse(m.preferences.islandPlacement.isCustom)
        XCTAssertEqual(restored.windowFrame.maxY, screen.frame.maxY, accuracy: 0.01)
    }
    @MainActor func testScreenRemovalKeepsFloatingPanelVisibleOnFallbackDisplay() {
        let m = LayoutTests().model(sessions: 1)
        let external = IslandDisplay(displayIdentifier: 444, frame: CGRect(x: -1800, y: -300, width: 1800, height: 1100), visibleFrame: CGRect(x: -1800, y: -270, width: 1800, height: 1040))
        var connected = [external, screen]
        m.preferences.islandPlacement = .init(displayID: 444, isCustom: true, x: 0.8, y: 0.2)
        let controller = IslandController(model: m, screens: { connected }); controller.layout(); defer { controller.stop() }
        XCTAssertTrue(external.visibleFrame.contains(controller.windowFrame))
        connected = [screen]; controller.layout()
        XCTAssertTrue(screen.visibleFrame.contains(controller.windowFrame))
    }
    @MainActor func testLosingAllScreensOrHidingDuringDragDoesNotLeaveDragLatched() {
        let m = LayoutTests().model(sessions: 1)
        var connected = [screen]
        let controller = IslandController(model: m, screens: { connected }); controller.layout(); defer { controller.stop() }
        controller.beginDrag(); connected = []; controller.layout()
        XCTAssertFalse(controller.isDragging); XCTAssertFalse(controller.presentation.visible)
        connected = [screen]; controller.layout()
        XCTAssertTrue(controller.presentation.visible)
        controller.beginDrag(); m.preferences.companionVisibility = .mascot; controller.layout()
        XCTAssertFalse(controller.isDragging); XCTAssertFalse(controller.presentation.visible)
        m.preferences.companionVisibility = .both; controller.layout()
        XCTAssertTrue(controller.presentation.visible)
    }
    @MainActor func testDraggingMidTransitionClipsToBoundsThenResumesFromRenderedSize() {
        let m = LayoutTests().model(sessions: 3)
        let controller = IslandController(model: m, screens: { [self] in [screen] }); controller.layout(); defer { controller.stop() }
        controller.expand(focus: false); RunLoop.main.run(until: Date().addingTimeInterval(0.08))
        controller.beginDrag()
        let anchor = CGPoint(x: controller.windowFrame.midX, y: controller.windowFrame.maxY)
        let target = CGPoint(x: screen.visibleFrame.minX + 100, y: screen.visibleFrame.minY + 50)
        controller.drag(by: CGPoint(x: target.x - anchor.x, y: target.y - anchor.y), at: target)
        XCTAssertTrue(screen.visibleFrame.contains(controller.windowFrame))
        controller.collapse(); XCTAssertEqual(controller.presentation.mode, .expanded)
        controller.endDrag(); RunLoop.main.run(until: Date().addingTimeInterval(0.45))
        XCTAssertTrue(controller.presentation.expandsUpward)
        XCTAssertTrue(screen.visibleFrame.contains(controller.windowFrame))
        XCTAssertGreaterThan(controller.windowFrame.height, 100)
    }
    @MainActor func testVisiblePinButtonReceivesClickWithoutStartingDragOrTogglingList() {
        let view = HeaderInputView(frame: CGRect(x: 0, y: 0, width: 180, height: 36))
        var pins = 0, clicks = 0, drags = 0
        view.pinToTop = { pins += 1 }; view.clicked = { clicks += 1 }; view.began = { drags += 1 }
        view.configurePin(visible: true, title: "Üste sabitle"); view.layout()
        XCTAssertFalse(view.pinButton.isHidden)
        XCTAssertTrue(view.hitTest(CGPoint(x: view.pinButton.frame.midX, y: view.pinButton.frame.midY)) === view.pinButton)
        view.pinButton.performClick(nil)
        XCTAssertEqual(pins, 1); XCTAssertEqual(clicks, 0); XCTAssertEqual(drags, 0)
        view.configurePin(visible: false, title: "Pin to top"); XCTAssertTrue(view.pinButton.isHidden)
    }
    @MainActor func testPinningClearsDragSuppressionAndSupportsHoverAndClickExpansion() {
        let m = LayoutTests().model(sessions: 1)
        m.preferences.islandPlacement = .init(displayID: screen.displayIdentifier, isCustom: true, x: 0.3, y: 0.3)
        let controller = IslandController(model: m, screens: { [self] in [screen] }); controller.layout(); defer { controller.stop() }
        XCTAssertFalse(controller.presentation.attachedToTop)
        controller.expand(focus: false)
        controller.presentation.pinToTop?()
        XCTAssertTrue(controller.presentation.attachedToTop); XCTAssertEqual(controller.presentation.mode, .compact)
        XCTAssertFalse(m.preferences.islandPlacement.isCustom)
        // Repeated mouse-move events must not keep postponing the hover timer.
        for _ in 0..<5 {
            controller.presentation.hover?(true)
            RunLoop.main.run(until: Date().addingTimeInterval(0.04))
        }
        XCTAssertEqual(controller.presentation.mode, .expanded)
        controller.presentation.hover?(false)
        RunLoop.main.run(until: Date().addingTimeInterval(0.50))
        XCTAssertEqual(controller.presentation.mode, .compact)
        controller.presentation.toggle?(); XCTAssertEqual(controller.presentation.mode, .expanded)
        controller.presentation.toggle?(); XCTAssertEqual(controller.presentation.mode, .compact)
        XCTAssertEqual(controller.windowFrame.maxY, screen.frame.maxY, accuracy: 0.01)
    }
    @MainActor func testHostingHoverTrackerRemainsActiveWhenAppIsInactive() {
        let m = LayoutTests().model(sessions: 1)
        let host = IslandHoverHostingView(rootView: IslandView(model: m, presentation: IslandPresentation()))
        host.frame = CGRect(x: 0, y: 0, width: 180, height: 36)
        host.updateTrackingAreas(); host.updateTrackingAreas()
        let areas = host.trackingAreas.filter { ($0.owner as? IslandHoverHostingView) === host && $0.options.contains(.activeAlways) }
        XCTAssertEqual(areas.count, 1)
        XCTAssertTrue(areas.first?.options.contains(.mouseEnteredAndExited) == true)
        XCTAssertTrue(areas.first?.options.contains(.inVisibleRect) == true)
        XCTAssertTrue(areas.first?.options.contains(.mouseMoved) == true)
    }
    @MainActor func testCancelAndDeferredAlertKeepInteractionState() throws {
        let m = LayoutTests().model(sessions: 1)
        m.preferences.displayID = screen.displayIdentifier
        let controller = IslandController(model: m, screens: { [self] in [screen] }); controller.layout(); defer { controller.stop() }
        let original = m.preferences.islandPlacement
        controller.beginDrag(); controller.drag(by: CGPoint(x: 100, y: -200), at: screen.visibleFrame.origin)
        controller.presentation.toggle?(); XCTAssertEqual(controller.presentation.mode, .compact)
        controller.alert("layout-0"); XCTAssertEqual(controller.presentation.mode, .compact)
        controller.endDrag(cancelled: true)
        XCTAssertEqual(m.preferences.islandPlacement, original)
        XCTAssertEqual(controller.presentation.mode, .alert)
        XCTAssertEqual(controller.windowFrame.maxY, screen.frame.maxY, accuracy: 0.01)
    }
}
