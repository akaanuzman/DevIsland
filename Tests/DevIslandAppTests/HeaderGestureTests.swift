import XCTest
import AppKit
import DevIslandCore
@testable import DevIslandApp

final class HeaderGestureTests: XCTestCase {
    let screen = IslandDisplay(displayIdentifier: 9001, frame: CGRect(x: 0, y: 0, width: 1440, height: 960), visibleFrame: CGRect(x: 0, y: 24, width: 1440, height: 892), topInset: 38, notchWidth: 190, isBuiltIn: true)
    @MainActor func testPressImmediatelyCancelsHoverAndClickStillOpensOnce() {
        let model = LayoutTests().model(sessions: 3)
        let c = IslandController(model: model, screens: { [self] in [screen] }); defer { c.stop() }
        c.layout(); c.presentation.hover?(true)
        let frame = c.windowFrame
        c.presentation.headerPressed?(CGPoint(x: frame.minX + 30, y: frame.maxY - 18))
        RunLoop.main.run(until: Date().addingTimeInterval(0.22))
        XCTAssertEqual(c.presentation.mode, .compact); XCTAssertEqual(c.windowFrame, frame)
        c.presentation.hover?(false); c.presentation.hover?(true)
        XCTAssertEqual(c.presentation.mode, .compact)
        c.presentation.headerReleased?(); c.presentation.toggle?()
        XCTAssertEqual(c.presentation.mode, .expanded)
    }
    @MainActor func testGrabPointSurvivesDetachmentAndNegativeOriginDisplayCoordinates() {
        let m = LayoutTests().model(sessions: 1)
        let external = IslandDisplay(displayIdentifier: 9002, frame: CGRect(x: -1920, y: -200, width: 1920, height: 1080), visibleFrame: CGRect(x: -1920, y: -170, width: 1920, height: 1020))
        let c = IslandController(model: m, screens: { [self] in [screen, external] }); defer { c.stop() }; c.layout()
        let fraction: CGFloat = 0.15
        let down = CGPoint(x: c.windowFrame.minX + c.presentation.headerWidth * fraction, y: c.windowFrame.maxY - 18)
        let verticalFraction = 18 / c.presentation.safeTop
        c.beginPress(at: down); c.beginDrag()
        for target in [CGPoint(x: 450,y:650), CGPoint(x: 700,y:450), CGPoint(x:-900,y:500)] {
            c.drag(by: CGPoint(x:target.x-down.x,y:target.y-down.y))
            let headerLeft = c.windowFrame.minX + c.presentation.headerOffset
            XCTAssertEqual(headerLeft + c.presentation.headerWidth * fraction, target.x, accuracy:1)
            XCTAssertEqual(c.windowFrame.maxY - 36 * verticalFraction, target.y, accuracy:1)
            XCTAssertFalse(c.presentation.attachedToTop)
        }
        c.endDrag(); XCTAssertEqual(m.preferences.islandPlacement.displayID, external.displayIdentifier)
        XCTAssertTrue(external.visibleFrame.contains(c.windowFrame))
    }
    @MainActor func testPressFreezesRunningAnimationAndDefersAlertUntilRelease() {
        let m = LayoutTests().model(sessions: 3)
        let c = IslandController(model:m,screens:{ [self] in [screen] }); defer { c.stop() }; c.layout()
        c.expand(focus:false); RunLoop.main.run(until:Date().addingTimeInterval(0.06))
        c.beginPress(at:CGPoint(x:c.windowFrame.midX,y:c.windowFrame.maxY-18))
        let frame = c.windowFrame, geometry = c.presentation.geometry
        RunLoop.main.run(until:Date().addingTimeInterval(0.4))
        XCTAssertEqual(c.windowFrame,frame); XCTAssertEqual(c.presentation.geometry,geometry)
        c.endDrag(cancelled:true)
        c.collapse(); RunLoop.main.run(until:Date().addingTimeInterval(0.3))
        c.beginPress(at:CGPoint(x:c.windowFrame.midX,y:c.windowFrame.maxY-18))
        c.alert("layout-1"); XCTAssertEqual(c.presentation.mode,.compact)
        c.endDrag(); XCTAssertEqual(c.presentation.mode,.alert); XCTAssertEqual(c.presentation.sessionID,"layout-1")
    }
    @MainActor func testCancelWhileOnlyPressedNeverBecomesClickAndGripHasRealHitTarget() {
        let v = HeaderInputView(frame:CGRect(x:0,y:0,width:352,height:36))
        var clicks=0,cancels=0,presses=0
        v.clicked={clicks+=1}; v.cancelled={cancels+=1}; v.pressedAction={_ in presses+=1}
        v.configurePin(visible:false,title:"Pin to top"); v.layout()
        XCTAssertEqual(v.grip.frame.size,CGSize(width:24,height:24))
        XCTAssertNotNil(v.grip.image?.tiffRepresentation)
        XCTAssertEqual(v.grip.image?.size, CGSize(width:10,height:14))
        XCTAssertTrue(v.hitTest(CGPoint(x:v.grip.frame.midX,y:v.grip.frame.midY)) === v)
        v.press(at:CGPoint(x:100,y:100));v.cancelOperation(nil);v.release()
        XCTAssertEqual(presses,1);XCTAssertEqual(cancels,1);XCTAssertEqual(clicks,0)
    }
    @MainActor func testRemovingDisplayDuringPressDoesNotLatchInput() {
        let m=LayoutTests().model(sessions:1)
        let other=IslandDisplay(displayIdentifier:9002,frame:CGRect(x:-1600,y:0,width:1600,height:900),visibleFrame:CGRect(x:-1600,y:24,width:1600,height:838))
        var screens=[screen,other]
        m.preferences.islandPlacement = .init(displayID:other.displayIdentifier,isCustom:true,x:0.5,y:0.5)
        let c=IslandController(model:m,screens:{screens});defer { c.stop() };c.layout()
        c.beginPress(at:CGPoint(x:c.windowFrame.midX,y:c.windowFrame.maxY-18))
        screens=[screen];c.layout();c.expand(focus:false)
        XCTAssertEqual(c.presentation.mode,.expanded);XCTAssertFalse(c.isDragging)
        XCTAssertTrue(screen.visibleFrame.contains(c.windowFrame))
    }
    @MainActor func testSnapRecomputesHoverFromFinalWindowRatherThanDraggedFrame() {
        let m=LayoutTests().model(sessions:1)
        var pointer=CGPoint.zero
        let c=IslandController(model:m,screens:{ [self] in [screen] },pointer:{pointer});defer { c.stop() };c.layout()
        let start=CGPoint(x:c.windowFrame.midX,y:c.windowFrame.maxY-18)
        c.beginPress(at:start);c.beginDrag()
        pointer=CGPoint(x:screen.frame.midX,y:screen.visibleFrame.maxY-17)
        c.drag(by:CGPoint(x:pointer.x-start.x,y:pointer.y-start.y));c.endDrag()
        XCTAssertTrue(c.presentation.attachedToTop)
        XCTAssertFalse(c.windowFrame.contains(pointer))
        c.presentation.hover?(true)
        RunLoop.main.run(until:Date().addingTimeInterval(0.18))
        XCTAssertEqual(c.presentation.mode,.expanded)
    }
    @MainActor func testAlertTimerPausesAtMouseDownBeforeDragThreshold() {
        let m=LayoutTests().model(sessions:1)
        let c=IslandController(model:m,screens:{ [self] in [screen] },pointer:{CGPoint(x:20,y:20)});defer { c.stop() };c.layout()
        c.alert("layout-0")
        c.beginPress(at:CGPoint(x:c.windowFrame.midX,y:c.windowFrame.maxY-18))
        RunLoop.main.run(until:Date().addingTimeInterval(8.1))
        XCTAssertEqual(c.presentation.mode,.alert)
        c.endDrag();RunLoop.main.run(until:Date().addingTimeInterval(0.2))
        XCTAssertEqual(c.presentation.mode,.alert)
    }
}
