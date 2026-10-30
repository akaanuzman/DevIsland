import XCTest
import DevIslandCore
@testable import DevIslandApp

final class SessionNameRefreshTests: XCTestCase {
    @MainActor func testBackfillOnlyChangesNameAndPreservesManualLabelsPrivacyAndState() {
        let m = LayoutTests().model(sessions: 2)
        let original = m.sessions[0], id = original.id
        var alerts = 0; m.presentAlert = { _ in alerts += 1 }
        m.applySessionNames([id: .init("improve-shop-experience", origin: .automatic)!])
        XCTAssertEqual(m.ledger.sessions[id]?.title, "improve-shop-experience")
        XCTAssertEqual(m.ledger.sessions[id]?.state, original.state)
        XCTAssertEqual(m.ledger.sessions[id]?.attentionSince, original.attentionSince)
        XCTAssertEqual(m.ledger.sessions[id]?.lastEvent, original.lastEvent)
        XCTAssertEqual(alerts, 0)
        m.ledger.sessions[id]?.label = "My label"
        m.applySessionNames([id: .init("renamed", origin: .custom)!])
        XCTAssertEqual(m.ledger.sessions[id]?.title, "My label")
        m.ledger.sessions[id]?.label = ""
        XCTAssertEqual(m.sessionPresentation(for: m.ledger.sessions[id]!).name, "renamed")
        m.preferences.hideProjects = true
        XCTAssertEqual(m.sessionPresentation(for: m.ledger.sessions[id]!).name, "Claude Code")
        m.applySessionNames([id: .init("old-registry", origin: .automatic)!])
        XCTAssertEqual(m.ledger.sessions[id]?.sessionName?.value, "renamed")
    }
    @MainActor func testBackgroundSnapshotCannotUndoANewerHookRename() {
        let m = LayoutTests().model(sessions: 1), id = m.sessions[0].id
        m.applySessionNames([id: .init("old-name", origin: .custom)!])
        let snapshot = m.sessions
        m.applySessionNames([id: .init("new-hook-name", origin: .custom)!])
        m.applySessionNames([id: .init("old-name", origin: .custom)!], baseline: snapshot)
        XCTAssertEqual(m.ledger.sessions[id]?.title, "new-hook-name")
    }
    @MainActor func testExistingIdleSessionsRefreshWithoutANewHookAndPickUpRename() async throws {
        let m = LayoutTests().model(sessions: 1), id = m.sessions[0].id
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("island-name-refresh-" + UUID().uuidString)
        let registry = root.appendingPathComponent("sessions/1.json")
        try FileManager.default.createDirectory(at: registry.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { m.stop(); try? FileManager.default.removeItem(at: root) }
        m.configPath = root.path
        func update(_ name: String) throws {
            let data = try JSONSerialization.data(withJSONObject: ["sessionId": id, "name": name, "nameSource":"auto"])
            try data.write(to: registry, options: .atomic)
        }
        for name in ["improve-shop-experience", "updated-name"] {
            try update(name); m.refreshSessionNames()
            for _ in 0..<100 {
                if m.ledger.sessions[id]?.sessionName?.value == name { break }
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            XCTAssertEqual(m.ledger.sessions[id]?.title, name)
            XCTAssertEqual(m.ledger.sessions[id]?.state, .question)
        }
    }
}
