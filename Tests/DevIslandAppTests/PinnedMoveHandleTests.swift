import XCTest
import AppKit
import DevIslandCore
@testable import DevIslandApp

final class PinnedMoveHandleTests: XCTestCase {
    let screen = IslandDisplay(displayIdentifier: 9100, frame: CGRect(x:0,y:0,width:1440,height:960), visibleFrame:CGRect(x:0,y:24,width:1440,height:892),topInset:38,notchWidth:190,isBuiltIn:true)
    @MainActor private func opened() -> (AppModel, IslandController) {
        let m=LayoutTests().model(sessions:3)
        let c=IslandController(model:m,screens:{ [self] in [screen] })
        c.layout();c.expand(focus:false)
        RunLoop.main.run(until:Date().addingTimeInterval(0.4))
        c.windowContentView?.layoutSubtreeIfNeeded()
        return (m,c)
    }
    @MainActor private func moveInput(_ c:IslandController) throws -> HeaderInputView {
        func inputs(_ v:NSView) -> [HeaderInputView] {
            (v as? HeaderInputView).map { [$0] } ?? v.subviews.flatMap(inputs)
        }
        let host=try XCTUnwrap(c.windowContentView)
        return try XCTUnwrap(inputs(host).first { $0.grip.isHidden && $0.bounds.width <= 70 })
    }
    @MainActor private func center(_ input:HeaderInputView) throws -> CGPoint {
        let window=try XCTUnwrap(input.window)
        return window.convertPoint(toScreen:input.convert(CGPoint(x:input.bounds.midX,y:input.bounds.midY),to:nil))
    }
    @MainActor private func event(_ type:NSEvent.EventType, at point:CGPoint, input:HeaderInputView) throws -> NSEvent {
        let window=try XCTUnwrap(input.window)
        return try XCTUnwrap(NSEvent.mouseEvent(with:type,location:window.convertPoint(fromScreen:point),modifierFlags:[],timestamp:0,windowNumber:window.windowNumber,context:nil,eventNumber:1,clickCount:1,pressure:type == .leftMouseUp ? 0:1))
    }
    @MainActor func testHandleIsAReal64By32TargetEntirelyBelowMenuBar() throws {
        let (_,c)=opened();defer { c.stop() }
        let input=try moveInput(c),host=try XCTUnwrap(c.windowContentView)
        let window=try XCTUnwrap(input.window)
        let rect=window.convertToScreen(input.convert(input.bounds,to:nil))
        XCTAssertEqual(rect.width,64,accuracy:1);XCTAssertEqual(rect.height,32,accuracy:1)
        XCTAssertLessThan(rect.maxY,screen.visibleFrame.maxY)
        for x in [3.0,input.bounds.width-3] {
            for y in [3.0,input.bounds.height-3] {
                let p=input.convert(CGPoint(x:x,y:y),to:host.superview)
                XCTAssertTrue(host.hitTest(p) === input)
            }
        }
        XCTAssertFalse(input.mouseDownCanMoveWindow)
        XCTAssertFalse(window.isMovable);XCTAssertFalse(window.isMovableByWindowBackground)
    }
    @MainActor func testNativeBodyHandleDragKeepsActualGrabPointAndDoesNotToggleList() throws {
        let (m,c)=opened();defer { c.stop() }
        let input=try moveInput(c),down=try center(input)
        input.mouseDown(with:try event(.leftMouseDown,at:down,input:input))
        RunLoop.main.run(until:Date().addingTimeInterval(0.2))
        XCTAssertEqual(c.presentation.mode,.expanded)
        let target=CGPoint(x:down.x-100,y:down.y-140)
        input.mouseDragged(with:try event(.leftMouseDragged,at:target,input:input))
        RunLoop.main.run(until:Date().addingTimeInterval(0.05))
        let moved=try center(try moveInput(c))
        XCTAssertEqual(moved.x,target.x,accuracy:1);XCTAssertEqual(moved.y,target.y,accuracy:1)
        XCTAssertTrue(c.isDragging);XCTAssertFalse(c.presentation.attachedToTop)
        input.mouseUp(with:try event(.leftMouseUp,at:target,input:input))
        XCTAssertFalse(c.isDragging);XCTAssertTrue(m.preferences.islandPlacement.isCustom)
        XCTAssertEqual(c.presentation.mode,.expanded)
    }
    @MainActor func testClickingBodyHandleDetachesIntoUsableScreenWithoutOpeningOrClosing() throws {
        let (m,c)=opened();defer { c.stop() }
        let input=try moveInput(c),point=try center(input)
        input.mouseDown(with:try event(.leftMouseDown,at:point,input:input))
        input.mouseUp(with:try event(.leftMouseUp,at:point,input:input))
        XCTAssertTrue(m.preferences.islandPlacement.isCustom)
        XCTAssertFalse(c.presentation.attachedToTop);XCTAssertEqual(c.presentation.mode,.expanded)
        XCTAssertEqual(c.windowFrame.maxY,screen.visibleFrame.maxY-16,accuracy:1)
        XCTAssertTrue(screen.visibleFrame.contains(c.windowFrame))
    }
    @MainActor func testUpdatingHeaderCannotStealBodyGestureCancellation() throws {
        let (m,c)=opened();defer { c.stop() }
        let old=m.preferences.islandPlacement,input=try moveInput(c),down=try center(input)
        input.mouseDown(with:try event(.leftMouseDown,at:down,input:input))
        let target=CGPoint(x:down.x-40,y:down.y-100)
        input.mouseDragged(with:try event(.leftMouseDragged,at:target,input:input))
        m.preferences.accentHex="AABBCC";c.layout()
        RunLoop.main.run(until:Date().addingTimeInterval(0.05))
        c.presentation.cancelHeaderInput?()
        input.mouseUp(with:try event(.leftMouseUp,at:target,input:input))
        XCTAssertFalse(c.isDragging);XCTAssertEqual(m.preferences.islandPlacement,old)
        XCTAssertTrue(c.presentation.attachedToTop);XCTAssertEqual(m.preferences.accentHex,"AABBCC")
    }
    @MainActor func testNotificationHandleCanMoveWithoutSwitchingToSessionList() throws {
        let m=LayoutTests().model(sessions:1)
        let c=IslandController(model:m,screens:{ [self] in [screen] });defer { c.stop() }
        c.layout();c.alert("layout-0");RunLoop.main.run(until:Date().addingTimeInterval(0.4))
        let input=try moveInput(c),down=try center(input),target=CGPoint(x:down.x-40,y:down.y-90)
        XCTAssertLessThan(down.y+16,screen.visibleFrame.maxY)
        input.mouseDown(with:try event(.leftMouseDown,at:down,input:input))
        input.mouseDragged(with:try event(.leftMouseDragged,at:target,input:input))
        RunLoop.main.run(until:Date().addingTimeInterval(0.05))
        let moved=try center(try moveInput(c))
        XCTAssertEqual(moved.x,target.x,accuracy:1);XCTAssertEqual(moved.y,target.y,accuracy:1)
        input.mouseUp(with:try event(.leftMouseUp,at:target,input:input))
        XCTAssertEqual(c.presentation.mode,.alert);XCTAssertEqual(c.presentation.sessionID,"layout-0")
    }
    @MainActor func testUpwardFloatingBodyAlsoKeepsGrabPoint() throws {
        let (m,c)=opened();defer { c.stop() }
        m.preferences.islandPlacement = .init(displayID:screen.displayIdentifier,isCustom:true,x:0.5,y:0.15)
        c.layout();RunLoop.main.run(until:Date().addingTimeInterval(0.4))
        XCTAssertTrue(c.presentation.expandsUpward)
        let input=try moveInput(c),down=try center(input),target=CGPoint(x:down.x+90,y:down.y+80)
        input.mouseDown(with:try event(.leftMouseDown,at:down,input:input))
        input.mouseDragged(with:try event(.leftMouseDragged,at:target,input:input))
        RunLoop.main.run(until:Date().addingTimeInterval(0.05))
        let moved=try center(try moveInput(c))
        XCTAssertEqual(moved.x,target.x,accuracy:1);XCTAssertEqual(moved.y,target.y,accuracy:1)
        input.cancelOperation(nil)
    }
}
