import XCTest
import AppKit
import SwiftUI
import DevIslandCore
@testable import DevIslandApp

final class CloseAndRecoveryTests: XCTestCase {
    @MainActor func testCloseControlHasFull32PointTargetAndAcceptsFirstClick() {
        _ = NSApplication.shared
        let button = IslandCloseControl(frame: CGRect(x: 0, y: 0, width: 32, height: 32))
        var calls = 0; button.closeAction = { calls += 1 }
        XCTAssertEqual(button.intrinsicContentSize, NSSize(width: 32, height: 32))
        XCTAssertTrue(button.acceptsFirstMouse(for: nil))
        for point in [CGPoint(x:1,y:1),CGPoint(x:31,y:1),CGPoint(x:1,y:31),CGPoint(x:31,y:31)] {
            XCTAssertTrue(button.hitTest(point) === button)
        }
        button.performClick(nil); XCTAssertEqual(calls, 1)
        XCTAssertEqual(button.keyEquivalent, "\u{1b}"); XCTAssertEqual(button.keyEquivalentModifierMask, [])
    }
    @MainActor func testActualIslandTreeRoutesCloseTargetWithoutHeaderInterception() throws {
        let m = LayoutTests().model(sessions: 3), p = IslandPresentation()
        p.mode = .expanded; p.bodyMode = .expanded
        let height = 36 + PanelSizing.height(of: SessionTrayView(model:m,close:{}),width:460,maximum:520)
        p.geometry = .init(width: 460, height: height, contentOpacity: 1)
        var closes = 0; p.collapse = { closes += 1 }
        let host = IslandHoverHostingView(rootView: IslandView(model:m,presentation:p)); host.sizingOptions = []
        let panel = NSPanel(contentRect:CGRect(x:100,y:100,width:460,height:height),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.isReleasedWhenClosed = false; defer { panel.close() }
        panel.contentView = host; host.frame = CGRect(x:0,y:0,width:460,height:height)
        host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.06))
        func buttons(_ view: NSView) -> [IslandCloseControl] {
            (view as? IslandCloseControl).map { [$0] } ?? view.subviews.flatMap(buttons)
        }
        let button = try XCTUnwrap(buttons(host).first)
        XCTAssertEqual(button.bounds.width, 32, accuracy: 0.1); XCTAssertEqual(button.bounds.height, 32, accuracy: 0.1)
        XCTAssertTrue(host.acceptsFirstMouse(for:nil))
        for point in [CGPoint(x:1,y:1),CGPoint(x:31,y:31)] {
            let hit = host.hitTest(button.convert(point, to:host.superview))
            print("Close hit: \(hit.map { String(describing:type(of:$0)) } ?? "nil"), native target: \(button.bounds.size)")
            XCTAssertTrue(hit === button)
        }
        button.performClick(nil); XCTAssertEqual(closes, 1)
        XCTAssertEqual(button.accessibilityLabel(), "Collapse")
    }
    @MainActor func testMascotTrayUsesTheSameNativeCloseTarget() throws {
        let m = LayoutTests().model(sessions:1)
        var closed = 0
        let host = PanelSizing.host(MascotTrayView(model:m,close:{closed += 1}))
        let height = PanelSizing.height(of:MascotTrayView(model:m,close:{}),width:400,maximum:580)
        let panel = NSPanel(contentRect:CGRect(x:100,y:100,width:400,height:height),styleMask:[.borderless],backing:.buffered,defer:false)
        panel.isReleasedWhenClosed = false; defer { panel.close() }
        panel.contentView = host; host.frame = CGRect(x:0,y:0,width:400,height:height)
        host.layoutSubtreeIfNeeded(); RunLoop.main.run(until:Date().addingTimeInterval(0.06))
        func find(_ view:NSView) -> IslandCloseControl? {
            if let button = view as? IslandCloseControl { return button }
            return view.subviews.compactMap(find).first
        }
        let button = try XCTUnwrap(find(host))
        XCTAssertTrue(host.hitTest(button.convert(CGPoint(x:1,y:1),to:host.superview)) === button)
        button.performClick(nil); XCTAssertEqual(closed,1)
    }
    @MainActor func controller(pointer: @escaping @MainActor () -> CGPoint) -> IslandController {
        let m = LayoutTests().model(sessions: 1)
        let screen = IslandDisplay(displayIdentifier: 990, frame: CGRect(x:0,y:0,width:1200,height:900), visibleFrame: CGRect(x:0,y:24,width:1200,height:838), topInset:38, notchWidth:190, isBuiltIn:true)
        let c = IslandController(model:m,screens:{[screen]},pointer:pointer); c.layout(); return c
    }
    @MainActor func testCloseIgnoresResizeHoverThenRequiresRealExitWhenPointerRemainsInside() {
        var pointer = CGPoint(x:600,y:881)
        let c = controller(pointer:{pointer}); defer { c.stop() }
        c.expand(focus:false); c.presentation.hover?(true)
        RunLoop.main.run(until: Date().addingTimeInterval(0.38))
        c.presentation.collapse?()
        c.presentation.hover?(false); c.presentation.hover?(true)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        XCTAssertEqual(c.presentation.mode,.compact)
        c.presentation.hover?(true); RunLoop.main.run(until: Date().addingTimeInterval(0.17))
        XCTAssertEqual(c.presentation.mode,.compact)
        pointer = .zero; c.presentation.hover?(false)
        pointer = CGPoint(x:600,y:881); c.presentation.hover?(true)
        RunLoop.main.run(until: Date().addingTimeInterval(0.18))
        XCTAssertEqual(c.presentation.mode,.expanded)
    }
    @MainActor func testPointerOutsideAfterCloseCanHoverOpenNormally() {
        var pointer = CGPoint.zero
        let c = controller(pointer:{pointer}); defer { c.stop() }
        c.expand(focus:false); RunLoop.main.run(until: Date().addingTimeInterval(0.38))
        c.dismiss(); RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        XCTAssertEqual(c.presentation.mode,.compact)
        pointer = CGPoint(x:600,y:881); c.presentation.hover?(true)
        RunLoop.main.run(until: Date().addingTimeInterval(0.18))
        XCTAssertEqual(c.presentation.mode,.expanded)
    }
    @MainActor func testOldCloseTaskCannotOverrideExplicitReopenOrNewAlert() {
        let c = controller(pointer:{CGPoint(x:600,y:881)}); defer { c.stop() }
        c.expand(focus:false); c.dismiss(); c.expand(focus:false)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        XCTAssertEqual(c.presentation.mode,.expanded)
        c.dismiss(); c.alert("layout-0")
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        XCTAssertEqual(c.presentation.mode,.alert); XCTAssertEqual(c.presentation.sessionID,"layout-0")
    }
    @MainActor func testMascotRecoveryPersistsAndIntentionallyHiddenPreferencesStayHiddenUntilRequested() throws {
        let m = LayoutTests().model(sessions: 0)
        m.preferences.mascotHidden = true; m.preferences.companionVisibility = .island
        m.preferences.mascotSize = 104; m.preferences.mascot = .cat; m.preferences.accentHex = "D97F4F"
        m.preferences.mascotPlacement = .init(displayID: 2, x: 0.9, y: 0.75)
        let loaded = AppModel(paths:m.paths,defaults:m.defaults,loadPersistentState:false)
        XCTAssertFalse(loaded.preferences.showsMascot)
        var updates = 0; loaded.settingsChanged = { updates += 1 }
        loaded.showDesktopMascot(resetPosition:true)
        XCTAssertTrue(loaded.preferences.showsMascot); XCTAssertEqual(loaded.preferences.companionVisibility,.both)
        XCTAssertEqual(loaded.preferences.mascotPlacement,MascotPlacement()); XCTAssertEqual(updates,1)
        let next = AppModel(paths:m.paths,defaults:m.defaults,loadPersistentState:false)
        XCTAssertTrue(next.preferences.showsMascot); XCTAssertEqual(next.preferences.mascotSize,104)
        XCTAssertEqual(next.preferences.mascot,.cat); XCTAssertEqual(next.preferences.accentHex,"D97F4F")
        for kind in MascotKind.allCases {
            next.preferences.mascot = kind
            let renderer = ImageRenderer(content: DesktopMascotView(model:next,active:false).environment(\.snapshotPreview,true))
            let image = try XCTUnwrap(renderer.cgImage)
            XCTAssertEqual(image.width,104); XCTAssertEqual(image.height,104)
            let pixels = try XCTUnwrap(image.dataProvider?.data) as Data
            XCTAssertTrue(pixels.contains { $0 != 0 }, "Desktop mascot rendered no pixels: \(kind)")
        }
    }
}
