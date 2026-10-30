import XCTest
@testable import DevIslandCore

final class SessionPresentationTests: XCTestCase {
    func session(_ state: SessionState, id: String = "one") -> AgentSession {
        var s = AgentSession(id: id, cwd: "/Projects/Cookify", lastEvent: Date(), source: .init())
        s.state = state; return s
    }
    func testEachSessionKeepsItsOwnPoseAndCelebrationClock() {
        let date = Date(timeIntervalSince1970: 100)
        let pairs: [(SessionState, ClawdPose)] = [(.idle, .idle), (.running, .working), (.question, .question),
            (.plan, .plan), (.permission, .permission), (.failed, .failed), (.disconnected, .disconnected), (.ended, .idle)]
        for (state, pose) in pairs {
            let p = SessionPresentation(session: session(state), hideProjects: false, celebrating: "another", celebrationStarted: date)
            XCTAssertEqual(p.pose, pose); XCTAssertEqual(p.state, state); XCTAssertNil(p.celebrationStarted)
        }
        let own = SessionPresentation(session: session(.completed), hideProjects: false, celebrating: "one", celebrationStarted: date)
        let other = SessionPresentation(session: session(.completed, id: "two"), hideProjects: false, celebrating: "one", celebrationStarted: date)
        XCTAssertEqual(own.pose, .celebration); XCTAssertEqual(own.celebrationStarted, date)
        XCTAssertEqual(other.pose, .idle); XCTAssertNil(other.celebrationStarted)
        XCTAssertEqual(own, SessionPresentation(session: session(.completed), hideProjects: false, celebrating: "one", celebrationStarted: date))
        XCTAssertEqual(SessionPresentation(session: session(.completed), hideProjects: false).pose, .idle)
    }
    func testLabelPrecedenceAndPrivacyApplyToEveryProjection() {
        var s = session(.question)
        XCTAssertEqual(SessionPresentation(session: s, hideProjects: false).name, "Cookify")
        s.label = "Checkout fix"
        XCTAssertEqual(SessionPresentation(session: s, hideProjects: false).name, "Checkout fix")
        XCTAssertEqual(SessionPresentation(session: s, hideProjects: true).name, "Claude Code")
        XCTAssertEqual(s.title, "Checkout fix")
    }
    func testHeaderBudgetReservesCameraAndIsIndependentOfSessionName() {
        for notch in [0.0, 190, 220] {
            let width = IslandHeaderLayout.width(notch: notch, available: 1512)
            let name = IslandHeaderLayout.nameWidth(header: width, notch: notch, detached: false)
            XCTAssertEqual(name, 120)
            if notch > 0 {
                let wing = (width - notch) / 2
                XCTAssertGreaterThanOrEqual(wing, 18 + 30 + 8 + name)
                XCTAssertEqual(wing + notch / 2, width / 2)
            }
            XCTAssertLessThanOrEqual(width, 1496)
        }
        XCTAssertEqual(IslandHeaderLayout.width(notch: 0, available: 320), 304)
        XCTAssertEqual(IslandHeaderLayout.nameWidth(header: 100, notch: 190, detached: false), 0)
        XCTAssertEqual(IslandHeaderLayout.nameWidth(header: 352, notch: 0, detached: true), 120)
    }
}
