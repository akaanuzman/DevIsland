import XCTest
import SwiftUI
import AppKit
import DevIslandCore
@testable import DevIslandApp

final class SessionMascotTests: XCTestCase {
    @MainActor func testHeaderFollowsAlertAndFallsBackWhenItDisappears() {
        let m = LayoutTests().model(sessions: 3)
        m.ledger.sessions["layout-0"]?.state = .running
        let priority = m.islandSession()!
        XCTAssertEqual(priority.state, .question)
        XCTAssertEqual(m.islandSession(alertSessionID: "layout-0")?.id, "layout-0")
        m.ledger.sessions["layout-0"]?.label = "Fix checkout"
        XCTAssertEqual(m.sessionPresentation(for: m.islandSession(alertSessionID: "layout-0")!).name, "Fix checkout")
        m.preferences.hideProjects = true
        XCTAssertEqual(m.sessionPresentation(for: priority).name, "Claude Code")
        m.ledger.sessions.removeValue(forKey: "layout-0")
        XCTAssertEqual(m.islandSession(alertSessionID: "layout-0")?.id, priority.id)
        m.ledger.sessions.removeAll()
        XCTAssertNil(m.islandSession())
    }
    @MainActor func testCompactHeaderHeightAndTitleBudgetAcrossCharactersAndThemes() {
        let m = LayoutTests().model(sessions: 10)
        for kind in MascotKind.allCases {
            m.preferences.mascot = kind
            for theme in [ThemeMode.light, .dark, .system] {
                m.preferences.theme = theme
                for notch in [0.0, 190.0] {
                    let p = IslandPresentation()
                    p.notchWidth = notch; p.headerWidth = IslandHeaderLayout.width(notch: notch, available: 1512)
                    p.safeTop = notch == 0 ? 36 : 44
                    p.geometry = .init(width: p.headerWidth, height: p.safeTop)
                    p.bodyMode = .expanded // Still mounted during a closing transition.
                    for label in ["Short", String(repeating: "Long title ", count: 20)] {
                        for id in m.ledger.sessions.keys { m.ledger.sessions[id]?.label = label }
                        let host = PanelSizing.host(IslandView(model: m, presentation: p))
                        host.frame = .init(x: 0, y: 0, width: p.headerWidth, height: p.safeTop)
                        host.layoutSubtreeIfNeeded()
                        XCTAssertEqual(host.frame.height, p.safeTop)
                        XCTAssertEqual(PanelSizing.height(of: IslandView(model: m, presentation: p), width: p.headerWidth, maximum: 10000), p.safeTop, accuracy: 1)
                    }
                }
            }
        }
    }
    @MainActor func testLiveCompletionSharesOneClockAndReopeningDoesNotRestartIt() async throws {
        let m = LayoutTests().model(sessions: 1)
        try m.paths.prepare()
        m.repository = try SessionRepository(root: m.paths.root)
        defer { m.stop(); try? FileManager.default.removeItem(at: m.paths.root) }
        for state in [SessionState.completed, .question] {
            m.preferences.rules[state.rawValue] = .init(island: false, notification: false, sound: false)
        }
        let id = "completed"
        m.handle(AgentEvent(sessionID: id, kind: .prompt, cwd: "/Projects/Finished"))
        let event = AgentEvent(sessionID: id, kind: .responseFinished, cwd: "/Projects/Finished")
        m.handle(event)
        try await Task.sleep(nanoseconds: 750_000_000)
        let session = try XCTUnwrap(m.ledger.sessions[id])
        let first = m.sessionPresentation(for: session)
        XCTAssertEqual(first.pose, .celebration)
        let start = try XCTUnwrap(first.celebrationStarted)
        XCTAssertNotEqual(m.companion.sessionID, id) // A separate question still wins global priority.
        let p = IslandPresentation(); p.mode = .alert; p.sessionID = id
        _ = PanelSizing.height(of: IslandAlertBody(model: m, sessionID: id, close: {}, showAll: {}), width: 460, maximum: 520)
        m.markCompletionsSeen()
        m.handle(event) // Duplicate delivery cannot restart the animation clock.
        XCTAssertEqual(m.sessionPresentation(for: session).celebrationStarted, start)
        XCTAssertNil(m.sessionPresentation(for: m.ledger.sessions["layout-0"]!).celebrationStarted)
        try await Task.sleep(nanoseconds: 1_650_000_000)
        XCTAssertEqual(m.sessionPresentation(for: session).pose, .idle)
        XCTAssertNil(m.sessionPresentation(for: session).celebrationStarted)
        m.handle(AgentEvent(sessionID: "replayed", kind: .responseFinished, cwd: "/Old"), replay: true)
        try await Task.sleep(nanoseconds: 700_000_000)
        XCTAssertEqual(m.sessionPresentation(for: m.ledger.sessions["replayed"]!).pose, .idle)
    }
    @MainActor func testSessionViewsRenderDistinctPosesAndKeepSettingsIcons() throws {
        let m = LayoutTests().model(sessions: 1)
        let s = m.sessions[0]
        let settingsRow = SessionRow(model: m, session: s)
        XCTAssertFalse(settingsRow.showsMascot)
        let row = SessionRow(model: m, session: s, compact: true, showsMascot: true, animationsActive: false)
        XCTAssertTrue(row.showsMascot); XCTAssertFalse(row.animationsActive)
        for kind in MascotKind.allCases {
            m.preferences.mascot = kind
            for state in [SessionState.running, .question, .plan, .permission, .completed, .failed, .disconnected] {
                var session = s; session.state = state
                let renderer = ImageRenderer(content: SessionMascotView(model: m, session: session, size: 44)
                    .environment(\.snapshotPreview, true))
                XCTAssertNotNil(renderer.cgImage)
            }
        }
    }
}
