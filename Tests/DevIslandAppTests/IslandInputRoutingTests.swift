import XCTest
import AppKit
import DevIslandCore
@testable import DevIslandApp

final class IslandInputRoutingTests: XCTestCase {
    @MainActor func testDockedInputIsAboveStatusBarAndBelowPhysicalCamera() {
        let m = LayoutTests().model(sessions: 1)
        let screen = IslandDisplay(displayIdentifier: 998, frame: CGRect(x:0,y:0,width:1200,height:900), visibleFrame: CGRect(x:0,y:24,width:1200,height:838), topInset: 38, notchWidth: 190, isBuiltIn: true)
        let controller = IslandController(model: m, screens: { [screen] }); controller.layout(); defer { controller.stop() }
        XCTAssertGreaterThan(controller.windowLevel.rawValue, NSWindow.Level.statusBar.rawValue, "System menu/status windows must not receive island clicks first")
        XCTAssertGreaterThan(controller.presentation.safeTop, screen.topInset, "A real pointer strip must exist below the physical camera cutout")
        controller.toggle()
        XCTAssertGreaterThan(controller.windowLevel.rawValue, NSWindow.Level.statusBar.rawValue)
        XCTAssertEqual(controller.presentation.mode, .expanded)
    }
    @MainActor func testMenuBarDeliveredHoverExpandsAndExitingCollapses() {
        let m = LayoutTests().model(sessions: 1)
        let screen = IslandDisplay(displayIdentifier: 998, frame: CGRect(x:0,y:0,width:1200,height:900), visibleFrame: CGRect(x:0,y:24,width:1200,height:838), topInset: 38, notchWidth: 190, isBuiltIn: true)
        let controller = IslandController(model: m, screens: { [screen] }); controller.layout(); defer { controller.stop() }
        for _ in 0..<5 {
            controller.handleDockedExternalPointer(at: CGPoint(x:600,y:881), clicked:false)
            RunLoop.main.run(until: Date().addingTimeInterval(0.04))
        }
        XCTAssertEqual(controller.presentation.mode, .expanded)
        controller.handleDockedExternalPointer(at: CGPoint(x:40,y:100), clicked:false)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        XCTAssertEqual(controller.presentation.mode, .compact)
    }
    @MainActor func testOnlyCameraAreaForeignClicksToggleAndFloatingAreaIsIgnored() {
        let m = LayoutTests().model(sessions: 1)
        let screen = IslandDisplay(displayIdentifier: 998, frame: CGRect(x:0,y:0,width:1200,height:900), visibleFrame: CGRect(x:0,y:24,width:1200,height:838), topInset: 38, notchWidth: 190, isBuiltIn: true)
        let controller = IslandController(model: m, screens: { [screen] }); controller.layout(); defer { controller.stop() }
        // A foreign app's menu/status click, even beside the camera, must remain its own action.
        controller.handleDockedExternalPointer(at: CGPoint(x:470,y:890), clicked:true)
        XCTAssertEqual(controller.presentation.mode, .compact)
        controller.handleDockedExternalPointer(at: CGPoint(x:600,y:881), clicked:true)
        XCTAssertEqual(controller.presentation.mode, .expanded)
        controller.handleDockedExternalPointer(at: CGPoint(x:600,y:881), clicked:true)
        XCTAssertEqual(controller.presentation.mode, .compact)
        m.preferences.islandPlacement = .init(displayID:998,isCustom:true,x:0.5,y:0.5); controller.layout()
        controller.handleDockedExternalPointer(at: CGPoint(x:600,y:881), clicked:true)
        XCTAssertEqual(controller.presentation.mode, .compact)
        XCTAssertEqual(controller.windowLevel, .floating)
    }
    @MainActor func testVisibleStripBelowCameraHasNativeClickTarget() throws {
        let model = LayoutTests().model(sessions: 1), p = IslandPresentation()
        p.headerWidth = 340; p.safeTop = 44; p.notchWidth = 190; p.geometry = .init(width:340,height:44)
        var clicks = 0; p.toggle = { clicks += 1 }
        let panel = IslandPanel(contentRect:CGRect(x:100,y:100,width:340,height:44),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.isReleasedWhenClosed = false; defer { panel.close() }
        let host = IslandHoverHostingView(rootView:IslandView(model:model,presentation:p)); host.sizingOptions = []; panel.contentView = host
        host.frame = CGRect(x:0,y:0,width:340,height:44); host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.06))
        let hit = try XCTUnwrap(host.hitTest(CGPoint(x:170,y:41)))
        XCTAssertTrue(hit is HeaderInputView)
        let down = try XCTUnwrap(NSEvent.mouseEvent(with:.leftMouseDown,location:CGPoint(x:170,y:41),modifierFlags:[],timestamp:0,windowNumber:panel.windowNumber,context:nil,eventNumber:1,clickCount:1,pressure:1))
        let up = try XCTUnwrap(NSEvent.mouseEvent(with:.leftMouseUp,location:CGPoint(x:170,y:41),modifierFlags:[],timestamp:0.01,windowNumber:panel.windowNumber,context:nil,eventNumber:2,clickCount:1,pressure:0))
        hit.mouseDown(with:down); hit.mouseUp(with:up); XCTAssertEqual(clicks,1)
    }
    @MainActor func testHostedHeaderGetsRealHitAndForwardsClick() throws {
        let model = LayoutTests().model(sessions: 1)
        let presentation = IslandPresentation()
        presentation.headerWidth = 340; presentation.safeTop = 38; presentation.notchWidth = 190
        presentation.geometry = .init(width: 340, height: 38)
        var clicked = 0; presentation.toggle = { clicked += 1 }
        let panel = IslandPanel(contentRect: CGRect(x: 100, y: 100, width: 340, height: 38), styleMask: [.borderless,.nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false; defer { panel.close() }
        let host = IslandHoverHostingView(rootView: IslandView(model: model, presentation: presentation))
        host.sizingOptions = []; panel.contentView = host
        host.frame = CGRect(x: 0, y: 0, width: 340, height: 38)
        host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.08))
        func all(_ v: NSView) -> [NSView] { [v] + v.subviews.flatMap(all) }
        let inputs = all(host).compactMap { $0 as? HeaderInputView }
        for input in inputs { print("Header input frame: \(input.frame), hidden: \(input.isHidden), click callback: \(input.clicked != nil)") }
        let input = try XCTUnwrap(inputs.first)
        XCTAssertEqual(input.bounds.width, 340, accuracy: 1)
        XCTAssertEqual(input.bounds.height, 38, accuracy: 1)
        let hit = try XCTUnwrap(host.hitTest(CGPoint(x: 32, y: 19)))
        print("Hosted hit receiver: \(type(of: hit))")
        XCTAssertTrue(hit === input)
        let down = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: CGPoint(x:32,y:19), modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        let up = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: CGPoint(x:32,y:19), modifierFlags: [], timestamp: 0.01, windowNumber: panel.windowNumber, context: nil, eventNumber: 2, clickCount: 1, pressure: 0))
        hit.mouseDown(with: down); hit.mouseUp(with: up)
        XCTAssertEqual(clicked, 1)
    }
}
