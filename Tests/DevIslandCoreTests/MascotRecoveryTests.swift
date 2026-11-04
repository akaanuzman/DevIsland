import XCTest
@testable import DevIslandCore

final class MascotRecoveryTests: XCTestCase {
    func testShowRestoresHiddenMascotWithoutChangingAppearanceOrPosition() throws {
        for mode in [CompanionVisibility.both, .island, .mascot] {
            var p = Preferences(); p.companionVisibility = mode; p.mascotHidden = true
            p.mascot = .robot; p.mascotSize = 104; p.accentHex = "D97F4F"; p.quiet = true
            p.mascotColors["robot"] = .init(mode: .custom, hex: "7EB4DA")
            p.mascotPlacement = .init(displayID: 2, x: 0.9, y: 0.75)
            let before = p
            p.showDesktopMascot()
            XCTAssertFalse(p.mascotHidden)
            XCTAssertEqual(p.companionVisibility, mode == .island ? .both : mode)
            XCTAssertEqual(p.mascotPlacement, before.mascotPlacement)
            XCTAssertEqual(p.mascotColors, before.mascotColors)
            XCTAssertEqual(p.mascot, before.mascot); XCTAssertEqual(p.mascotSize, before.mascotSize)
            XCTAssertEqual(p.accentHex, before.accentHex); XCTAssertTrue(p.quiet)
            XCTAssertEqual(p.rules, before.rules)
        }
    }
    func testExplicitRecoveryResetsOnlyMascotPlacement() {
        var p = Preferences(); p.mascotHidden = true
        p.mascotPlacement = .init(displayID: 2, x: 0.1, y: 0.8)
        p.islandPlacement = .init(displayID: 3, isCustom: true, x: 0.25, y: 0.5)
        let island = p.islandPlacement
        p.showDesktopMascot(resetPosition: true)
        XCTAssertFalse(p.mascotHidden); XCTAssertEqual(p.mascotPlacement, MascotPlacement())
        XCTAssertEqual(p.islandPlacement, island)
    }
    func testManualDismissalInvalidatesHoverAndWaitsForExit() {
        var i = IslandInteraction(); let old = i.enter()
        i.dismiss()
        XCTAssertFalse(i.permits(old, opening: true))
        i.finishDismissal(hovered: true)
        let suppressed = i.enter(); XCTAssertFalse(i.permits(suppressed, opening: true))
        _ = i.leave()
        let reentered = i.enter(); XCTAssertTrue(i.permits(reentered, opening: true))
        i.dismiss(); i.finishDismissal(hovered: false)
        let outsideThenEntered = i.enter(); XCTAssertTrue(i.permits(outsideThenEntered, opening: true))
    }
}
