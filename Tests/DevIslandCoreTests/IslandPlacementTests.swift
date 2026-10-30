import XCTest
import CoreGraphics
@testable import DevIslandCore

final class IslandPlacementTests: XCTestCase {
    let screen = CGRect(x: -1920, y: 100, width: 1920, height: 1080)
    let visible = CGRect(x: -1920, y: 150, width: 1920, height: 1000)
    let header = CGSize(width: 180, height: 36)
    func testLegacyPreferencesKeepSettingsAndStartAtPhysicalTop() throws {
        let p = try JSONDecoder().decode(Preferences.self, from: Data(#"{"quiet":true,"accentHex":"A12CF0","displayID":7}"#.utf8))
        XCTAssertEqual(p.islandPlacement, .init()); XCTAssertTrue(p.quiet); XCTAssertEqual(p.accentHex, "A12CF0"); XCTAssertEqual(p.displayID, 7)
        let anchor = IslandLayout.anchor(placement: p.islandPlacement, screen: screen, visible: visible, header: header)
        let frame = IslandLayout.frame(anchor: anchor, size: header, headerHeight: 36, visible: screen, upward: false)
        XCTAssertEqual(frame.maxY, screen.maxY); XCTAssertGreaterThan(frame.maxY, visible.maxY)
        XCTAssertEqual(frame.midX, screen.midX); XCTAssertTrue(anchor.attachedToTop)
    }
    func testCustomPlacementRoundTripsWithoutResettingUnrelatedPreferences() throws {
        var p = Preferences(); p.islandPlacement = .init(displayID: 5, isCustom: true, x: 0.3, y: 0.2)
        p.volume = 0.17; p.mascot = .cat; p.mascotColors["cat"] = .init(mode: .custom, hex: "ABC123")
        let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(restored.islandPlacement, p.islandPlacement); XCTAssertEqual(restored.volume, 0.17)
        XCTAssertEqual(restored.mascotHex, "ABC123")
        let a = IslandLayout.anchor(placement: restored.islandPlacement, screen: screen, visible: visible, header: header)
        let saved = IslandLayout.placement(anchor: a, screen: screen, visible: visible, displayID: 5)
        XCTAssertEqual(saved.x, 0.3, accuracy: 0.0001); XCTAssertEqual(saved.y, 0.2, accuracy: 0.0001)
    }
    func testRestoringOnSmallerReplacementScreenClampsTheEntireHeader() {
        let replacement = CGRect(x: 100, y: -900, width: 720, height: 480)
        for x in [-10.0, 0, 0.5, 1, 100, .infinity] {
            for y in [-10.0, 0, 0.5, 1, 100] {
                let a = IslandLayout.anchor(placement: .init(displayID: 999, isCustom: true, x: x, y: y), screen: replacement, visible: replacement, header: header)
                let f = IslandLayout.frame(anchor: a, size: header, headerHeight: 36, visible: replacement, upward: false)
                XCTAssertTrue(replacement.contains(f), "\(f)")
            }
        }
    }
    func testNearBottomOpensUpwardAndPreservesHeaderWhenResizing() {
        let a = IslandLayout.anchor(placement: .init(isCustom: true, x: 0.05, y: 0.1), screen: screen, visible: visible, header: header)
        XCTAssertTrue(IslandLayout.opensUpward(anchor: a, visible: visible, headerHeight: 36))
        for width in [180.0, 310, 460] {
            for height in [36.0, 150, 400] {
                let f = IslandLayout.frame(anchor: a, size: CGSize(width: width, height: height), headerHeight: 36, visible: visible, upward: true)
                XCTAssertEqual(f.minY + 36, a.headerTop, accuracy: 0.001)
                XCTAssertTrue(visible.contains(f))
                let headerLeft = a.centerX - f.minX - 90
                XCTAssertGreaterThanOrEqual(headerLeft, 0); XCTAssertLessThanOrEqual(headerLeft + 180, width)
            }
        }
    }
    func testNearTopOpensDownwardAndBodyRoomCapsToScreen() {
        let a = IslandLayout.anchor(placement: .init(isCustom: true, x: 0.99, y: 0.9), screen: screen, visible: visible, header: header)
        XCTAssertFalse(IslandLayout.opensUpward(anchor: a, visible: visible, headerHeight: 36))
        let room = IslandLayout.bodyRoom(anchor: a, visible: visible, headerHeight: 36, upward: false)
        let f = IslandLayout.frame(anchor: a, size: CGSize(width: 460, height: room + 36), headerHeight: 36, visible: visible, upward: false)
        XCTAssertEqual(f.maxY, a.headerTop); XCTAssertTrue(visible.contains(f))
    }
    func testDraggingNearTopCenterSnapsButOtherLocationsStayCustom() {
        let center = IslandAnchor(centerX: screen.midX + 10, headerTop: visible.maxY - 5)
        XCTAssertFalse(IslandLayout.placement(anchor: center, screen: screen, visible: visible, displayID: 8).isCustom)
        XCTAssertTrue(IslandLayout.placement(anchor: center, screen: screen, visible: visible, displayID: 8, snap: false).isCustom)
        let other = IslandAnchor(centerX: screen.minX + 180, headerTop: visible.maxY)
        XCTAssertTrue(IslandLayout.placement(anchor: other, screen: screen, visible: visible, displayID: 8).isCustom)
    }
    func testPointerJitterRemainsClickButDraggingBackToStartRemainsDrag() {
        var g = IslandDragGesture(); g.press(at: .zero)
        XCTAssertFalse(g.move(to: CGPoint(x: 2, y: 2))); XCTAssertFalse(g.release())
        g.press(at: .zero); XCTAssertTrue(g.move(to: CGPoint(x: 4, y: 0)))
        XCTAssertTrue(g.move(to: .zero)); XCTAssertTrue(g.release())
        XCTAssertFalse(g.move(to: CGPoint(x: 100, y: 100)))
        g.press(at: .zero); _ = g.move(to: CGPoint(x: 10, y: 10)); g.cancel(); XCTAssertFalse(g.release())
    }
    func testDragInvalidatesHoverCallbacksAndSuppressesReopenUntilExit() {
        var interaction = IslandInteraction()
        let open = interaction.enter(); interaction.beginDrag()
        XCTAssertFalse(interaction.permits(open, opening: true))
        interaction.endDrag(hovered: true)
        let hoverAfterDrop = interaction.enter()
        XCTAssertFalse(interaction.permits(hoverAfterDrop, opening: true))
        _ = interaction.leave(); let nextOpen = interaction.enter()
        XCTAssertTrue(interaction.permits(nextOpen, opening: true))
        interaction.pin(); interaction.beginDrag(); interaction.endDrag(hovered: false)
        XCTAssertTrue(interaction.pinned)
    }
    func testDockingResetsDragHoverSuppressionAndRejectsStaleCallbacks() {
        var interaction = IslandInteraction()
        let stale = interaction.enter(); interaction.beginDrag(); interaction.endDrag(hovered: true)
        interaction.pin(); interaction.resetForDock()
        XCTAssertFalse(interaction.pinned); XCTAssertFalse(interaction.hoverSuppressed); XCTAssertFalse(interaction.hovered)
        XCTAssertFalse(interaction.permits(stale, opening: true))
        let fresh = interaction.enter(); XCTAssertTrue(interaction.permits(fresh, opening: true))
    }
    func testAccentResetOnlyChangesAccentAndIsIdempotent() throws {
        var p = Preferences(); p.accentHex = "123456"; p.quiet = true; p.volume = 0.31; p.mascot = .robot
        p.mascotColors["robot"] = .init(mode: .custom, hex: "ABCDEF")
        let before = p
        p.resetAccent(); XCTAssertEqual(p.accentHex, "D97757")
        XCTAssertEqual(p.mascotColors, before.mascotColors); XCTAssertEqual(p.quiet, before.quiet); XCTAssertEqual(p.volume, before.volume)
        p.resetAccent(); XCTAssertEqual(p.accentHex, "D97757")
    }
    func testCharacterResetRestoresFollowingAccentAndPreservesOtherCharacters() throws {
        var p = Preferences(); p.accentHex = "123456"; p.mascot = .cat; p.quiet = true
        p.mascotColors["cat"] = .init(mode: .custom, hex: "AABBCC")
        p.mascotColors["robot"] = .init(mode: .custom, hex: "010203")
        p.resetSelectedMascotColor()
        XCTAssertEqual(p.selectedMascotColor.mode, .accent); XCTAssertEqual(p.mascotHex, "123456")
        XCTAssertEqual(p.mascotColors["robot"]?.hex, "010203"); XCTAssertTrue(p.quiet)
        let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(p))
        XCTAssertNil(restored.mascotColors["cat"]); XCTAssertEqual(restored.mascotHex, "123456")
        p.resetSelectedMascotColor(); XCTAssertNil(p.mascotColors["cat"])
    }
}
