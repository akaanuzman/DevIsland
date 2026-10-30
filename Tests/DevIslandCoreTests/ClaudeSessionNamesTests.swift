import XCTest
@testable import DevIslandCore

final class ClaudeSessionNamesTests: XCTestCase {
    var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("island-names-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }
    func write(_ path: String, _ text: String) throws -> URL {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url); return url
    }
    func testHookCustomTitleHasPriorityWithoutConsultingTheFilesystem() throws {
        var calls = 0
        let data = Data(#"{"session_id":"one","cwd":"/out","hook_event_name":"UserPromptSubmit","session_title":"  fix\ncheckout\u001b  ","prompt":"SECRET"}"#.utf8)
        let event = try XCTUnwrap(ClaudeAdapter.decode(data, nameLookup: { _,_ in calls += 1; return .init("wrong", origin: .automatic) }))
        XCTAssertEqual(event.sessionName?.value, "fix checkout"); XCTAssertEqual(event.sessionName?.origin, .custom)
        XCTAssertEqual(calls, 0)
        XCTAssertFalse(String(data: try JSONEncoder().encode(event), encoding: .utf8)!.contains("SECRET"))
    }
    func testRegistryBackfillsDifferentNamesInTheSameProjectBySessionID() throws {
        try write("sessions/1.json", #"{"sessionId":"one","name":"improve-shop-experience","nameSource":"auto","cwd":"/Projects/Shared"}"#)
        try write("sessions/2.json", #"{"sessionId":"two","name":"alvi-app-store-launch-prep","nameSource":"auto","cwd":"/Projects/Shared"}"#)
        try write("sessions/3.json", #"{"sessionId":"three","name":"folder-deadbeef","nameSource":"derived"}"#)
        let stale = try write("sessions/99.json", #"{"sessionId":"one","name":"stale-process","nameSource":"auto"}"#)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1)], ofItemAtPath: stale.path)
        let sessions = ["one","two","three"].map { AgentSession(id: $0, cwd: "/out", lastEvent: Date(), source: .init()) }
        let found = ClaudeSessionNames.lookup(sessions: sessions, configDirectory: root)
        XCTAssertEqual(found["one"]?.value, "improve-shop-experience")
        XCTAssertEqual(found["two"]?.value, "alvi-app-store-launch-prep")
        XCTAssertNil(found["three"])
    }
    func testTranscriptReadsOnlyMatchingNameMetadataAndCustomRenameWins() throws {
        let file = try write("projects/project/one.jsonl", """
        {"type":"user","sessionId":"one","message":"SECRET prompt"}
        {"type":"agent-name","sessionId":"one","agentName":"first"}
        {"type":"custom-title","sessionId":"one","customTitle":"manual-first"}
        {"type":"custom-title","sessionId":"different","customTitle":"WRONG"}
        {"type":"agent-name","sessionId":"one","agentName":"latest-auto"}
        {"type":"custom-title","sessionId":"one","customTitle":"manual-latest"}
        {"type":"summary","sessionId":"one","summary":"SECRET summary"}
        """)
        let name = ClaudeSessionNames.transcriptName(at: file, sessionID: "one", configDirectory: root)
        XCTAssertEqual(name?.value, "manual-latest"); XCTAssertEqual(name?.origin, .custom)
        XCTAssertNil(ClaudeSessionNames.transcriptName(at: file, sessionID: "different", configDirectory: root))
        XCTAssertEqual(ClaudeSessionNames.resolve(sessionID: "one", transcriptPath: file.path, configDirectory: root)?.value, "manual-latest")
    }
    func testBoundedTailHandlesHugeLinesPartialWritesAndLatestAgentName() throws {
        let file = try write("projects/p/one.jsonl", String(repeating: "x", count: 1024 * 1024) + "\n" + """
        {"type":"agent-name","sessionId":"one","agentName":"old"}
        {"type":"agent-name","sessionId":"one","agentName":"latest"}
        {"type":"custom-title","sessionId":"one","customTitle":
        """)
        XCTAssertEqual(ClaudeSessionNames.transcriptName(at: file, sessionID: "one", configDirectory: root)?.value, "latest")
    }
    func testUnsafePathsSymlinksAndUnrelatedSessionIDsAreIgnored() throws {
        let outside = try write("outside/one.jsonl", #"{"type":"agent-name","sessionId":"one","agentName":"unsafe"}"#)
        XCTAssertNil(ClaudeSessionNames.transcriptName(at: outside, sessionID: "one", configDirectory: root))
        let link = root.appendingPathComponent("projects/p/one.jsonl")
        try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        XCTAssertNil(ClaudeSessionNames.transcriptName(at: link, sessionID: "one", configDirectory: root))
        XCTAssertNil(ClaudeSessionNames.resolve(sessionID: "../one", transcriptPath: outside.path, configDirectory: root))
        try write("sessions/1.json", #"{"sessionId":"different","name":"wrong","nameSource":"auto"}"#)
        XCTAssertNil(ClaudeSessionNames.resolve(sessionID: "one", transcriptPath: nil, configDirectory: root, processID: 1))
    }
    func testRegisteredCwdFindsRenameEvenWhenHookCwdIsOut() throws {
        try write("sessions/7.json", #"{"sessionId":"one","name":"old-auto","nameSource":"auto","cwd":"/Projects/Shared"}"#)
        try write("projects/-Projects-Shared/one.jsonl", #"{"type":"custom-title","sessionId":"one","customTitle":"new-title"}"#)
        let s = AgentSession(id: "one", cwd: "/out", lastEvent: Date(), source: .init())
        XCTAssertEqual(ClaudeSessionNames.lookup(sessions: [s], configDirectory: root)["one"]?.value, "new-title")
    }
    func testLegacyDecodeNamePersistenceLabelPrecedenceAndStaleEvents() throws {
        var ledger = SessionLedger()
        let event = AgentEvent(sessionID: "one", kind: .prompt, cwd: "/Project")
        ledger.apply(event)
        var old = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger.sessions["one"]!)) as! [String: Any]
        old.removeValue(forKey: "sessionName")
        let restored = try JSONDecoder().decode(AgentSession.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertNil(restored.sessionName); XCTAssertEqual(restored.title, "Project")
        ledger.apply(AgentEvent(sessionID: "one", timestamp: event.timestamp.addingTimeInterval(1), kind: .toolStarted, cwd: "/Project", sessionName: .init("real-session", origin: .custom)))
        ledger.apply(AgentEvent(sessionID: "one", timestamp: event.timestamp, kind: .prompt, cwd: "/Project", sessionName: .init("stale", origin: .custom)))
        ledger.apply(AgentEvent(sessionID: "one", timestamp: event.timestamp.addingTimeInterval(2), kind: .toolStarted, cwd: "/Project", sessionName: .init("automatic", origin: .automatic)))
        XCTAssertEqual(ledger.sessions["one"]?.title, "real-session")
        ledger.sessions["one"]?.label = "My label"
        XCTAssertEqual(ledger.sessions["one"]?.title, "My label")
        let saved = try JSONDecoder().decode(SessionLedger.self, from: JSONEncoder().encode(ledger.persistentCopy))
        XCTAssertEqual(saved.sessions["one"]?.sessionName?.value, "real-session")
        XCTAssertEqual(saved.sessions["one"]?.label, "My label")
    }
    func testNameNormalizationAndNoConversationFallback() throws {
        XCTAssertNil(ClaudeSessionName("\n\u{001b}", origin: .automatic))
        XCTAssertEqual(ClaudeSessionName(String(repeating: "a", count: 1000), origin: .automatic)?.value.count, 200)
        let file = try write("projects/p/one.jsonl", #"{"type":"user","sessionId":"one","content":"agent-name SECRET"}"#)
        XCTAssertNil(ClaudeSessionNames.transcriptName(at: file, sessionID: "one", configDirectory: root))
    }
}
