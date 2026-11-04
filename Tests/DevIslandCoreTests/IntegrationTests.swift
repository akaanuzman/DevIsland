import XCTest
@testable import DevIslandCore

final class IntegrationTests: XCTestCase {
    var temporary: URL!
    override func setUpWithError() throws {
        temporary = FileManager.default.temporaryDirectory.appendingPathComponent("dev-island-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: temporary) }
    func testAdapterWhitelistsOnlyMetadata() throws {
        let raw: [String: Any] = ["hook_event_name": "PreToolUse", "session_id": "s", "cwd": "/project", "tool_name": "AskUserQuestion", "tool_use_id": "q", "prompt": "SECRET_PROMPT",
            "transcript_path": "/secret/transcript", "tool_input": ["questions": [["question": "PRIVATE_QUESTION"]], "command": "SECRET_COMMAND"]]
        let event = try XCTUnwrap(ClaudeAdapter.decode(JSONSerialization.data(withJSONObject: raw)))
        XCTAssertEqual(event.kind, .question)
        XCTAssertEqual(event.preview, "PRIVATE_QUESTION")
        let encoded = String(decoding: try JSONEncoder().encode(event.withoutPreview), as: UTF8.self)
        for secret in ["SECRET_PROMPT", "PRIVATE_QUESTION", "SECRET_COMMAND", "/secret/transcript"] { XCTAssertFalse(encoded.contains(secret)) }
    }
    func testSubagentStopCannotCompleteMainSession() throws {
        let data = Data(#"{"hook_event_name":"Stop","session_id":"s","agent_id":"child"}"#.utf8)
        XCTAssertNil(try ClaudeAdapter.decode(data))
    }
    func testUnknownNotificationsAreIgnored() throws {
        let data = Data(#"{"hook_event_name":"Notification","session_id":"s","notification_type":"auth_success"}"#.utf8)
        XCTAssertNil(try ClaudeAdapter.decode(data))
    }
    func testQueueNeverPersistsPreviewAndSurvivesWithoutApp() throws {
        let paths = AppPaths(root: temporary.appendingPathComponent("data"))
        let event = AgentEvent(sessionID: "s", kind: .question, cwd: "/project", preview: "PRIVATE_QUESTION")
        try EventQueue.enqueue(event, paths: paths)
        let files = try EventQueue.pending(paths: paths)
        XCTAssertEqual(files.count, 1)
        let restored = try EventQueue.read(files[0])
        XCTAssertEqual(restored.id, event.id); XCTAssertNil(restored.preview)
        EventQueue.acknowledge(event, paths: paths)
        XCTAssertTrue(try EventQueue.pending(paths: paths).isEmpty)
    }
    func testInstallerPreservesExistingMixedHooksAndIsIdempotent() throws {
        let config = temporary.appendingPathComponent("claude")
        let paths = AppPaths(root: temporary.appendingPathComponent("app"))
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        let original: [String: Any] = ["theme": "dark", "permissions": ["allow": ["Read"]], "hooks": ["Stop": [["matcher": "", "hooks": [["type": "command", "command": "echo existing"], ["type": "http", "url": "https://example.invalid/hook"]]]]]]
        let settings = config.appendingPathComponent("settings.json")
        try JSONSerialization.data(withJSONObject: original).write(to: settings)
        let helper = temporary.appendingPathComponent("test-helper")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: helper)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path)
        let installer = HookInstaller(configDirectory: config, paths: paths)
        try installer.install(helper: helper)
        XCTAssertTrue(try installer.inspect().installed)
        try installer.install(helper: helper)
        var object = try JSONSerialization.jsonObject(with: Data(contentsOf: settings)) as! [String: Any]
        let hooks = object["hooks"] as! [String: Any]
        XCTAssertEqual((hooks["Stop"] as! [[String: Any]]).count, 2)
        XCTAssertEqual(object["theme"] as? String, "dark")
        object["newUserSetting"] = "preserve-me"
        try JSONSerialization.data(withJSONObject: object).write(to: settings)
        try installer.uninstall()
        let restored = try JSONSerialization.jsonObject(with: Data(contentsOf: settings)) as! [String: Any]
        XCTAssertEqual(restored["newUserSetting"] as? String, "preserve-me")
        let restoredHooks = restored["hooks"] as! [String: Any]
        XCTAssertEqual((restoredHooks["Stop"] as! [[String: Any]]).count, 1)
        let group = (restoredHooks["Stop"] as! [[String: Any]])[0]
        XCTAssertEqual((group["hooks"] as! [[String: Any]]).count, 2)
        XCTAssertFalse(try installer.inspect().installed)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: config.path).contains { $0.hasPrefix("settings.dev-island-backup-") })
    }
    func testUpdatedHelperIsAtomicAndDoesNotRewriteClaudeSettings() throws {
        let paths = AppPaths(root: temporary.appendingPathComponent("refresh-app"))
        let config = temporary.appendingPathComponent("refresh-claude")
        let installer = HookInstaller(configDirectory: config, paths: paths)
        let source = temporary.appendingPathComponent("bundled-helper")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: source)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: source.path)
        XCTAssertFalse(try installer.refreshInstalledHelper(from: source))
        try installer.install(helper: source)
        let settings = try Data(contentsOf: installer.settingsURL)
        let backupCount = try FileManager.default.contentsOfDirectory(atPath: config.path).count
        try Data("#!/bin/sh\n# new build\nexit 0\n".utf8).write(to: source)
        XCTAssertTrue(try installer.refreshInstalledHelper(from: source))
        XCTAssertFalse(try installer.refreshInstalledHelper(from: source))
        XCTAssertEqual(try Data(contentsOf: paths.helper), try Data(contentsOf: source))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: paths.helper.path))
        XCTAssertEqual(try Data(contentsOf: installer.settingsURL), settings)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: config.path).count, backupCount)
        try installer.uninstall()
        XCTAssertFalse(try installer.refreshInstalledHelper(from: source))
    }
    func testInvalidSettingsAreNotOverwritten() throws {
        let config = temporary.appendingPathComponent("claude")
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        let data = Data("{broken-json".utf8)
        let settings = config.appendingPathComponent("settings.json"); try data.write(to: settings)
        let installer = HookInstaller(configDirectory: config, paths: .init(root: temporary.appendingPathComponent("app")))
        XCTAssertThrowsError(try installer.uninstall())
        XCTAssertEqual(try Data(contentsOf: settings), data)
    }
    func testDisabledHooksAreReported() throws {
        let config = temporary.appendingPathComponent("claude")
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        try Data(#"{"disableAllHooks":true}"#.utf8).write(to: config.appendingPathComponent("settings.json"))
        let installer = HookInstaller(configDirectory: config)
        XCTAssertTrue(try installer.inspect().blocked)
    }
    func testSymlinkSettingsAreRejected() throws {
        let target = temporary.appendingPathComponent("other.json")
        try Data("{}".utf8).write(to: target)
        let config = temporary.appendingPathComponent("claude")
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: config.appendingPathComponent("settings.json"), withDestinationURL: target)
        XCTAssertThrowsError(try HookInstaller(configDirectory: config).inspect())
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "{}")
    }
}
