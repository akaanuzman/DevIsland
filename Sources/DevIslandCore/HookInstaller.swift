import Foundation
import Darwin

public enum HookInstallerError: LocalizedError {
    case invalidSettings, policyBlocked, unsafePath, missingHelper, settingsChanged
    public var errorDescription: String? {
        switch self {
        case .invalidSettings: return "Claude settings are not a valid JSON object. The file was not changed."
        case .policyBlocked: return "Claude hooks are disabled by settings or managed policy."
        case .unsafePath: return "A settings file or directory is a symbolic link. Choose a real Claude configuration directory."
        case .missingHelper: return "The bundled event bridge is missing. Build and launch the .app bundle."
        case .settingsChanged: return "Claude settings changed during installation. Nothing was overwritten; retry the operation."
        }
    }
}

public struct HookInstaller {
    public static let owner = "--owner dev-island.v1"
    public let configDirectory: URL
    public let paths: AppPaths
    public var settingsURL: URL { configDirectory.appendingPathComponent("settings.json") }
    public init(configDirectory: URL? = nil, paths: AppPaths = .init()) {
        self.configDirectory = configDirectory ?? ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
        self.paths = paths
    }
    public var command: String {
        "'" + paths.helper.path.replacingOccurrences(of: "'", with: "'\\''") + "' --claude-hook " + Self.owner
    }
    public var entries: [String: Any] {
        var hooks: [String: Any] = [:]
        for event in ["SessionStart", "SessionEnd", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure", "PermissionRequest", "Stop", "StopFailure", "SubagentStart", "SubagentStop"] {
            hooks[event] = [["hooks": [["type": "command", "command": command, "timeout": 2]]]]
        }
        hooks["Notification"] = [["matcher": "permission_prompt|elicitation_dialog|elicitation_url_dialog|agent_needs_input",
                                  "hooks": [["type": "command", "command": command, "timeout": 2]]]]
        return hooks
    }
    public var preview: String {
        String(data: (try? JSONSerialization.data(withJSONObject: ["hooks": entries], options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])) ?? Data(), encoding: .utf8) ?? ""
    }
    public func inspect() throws -> (installed: Bool, blocked: Bool) {
        let object = try read()
        let hooks = object["hooks"] as? [String: Any] ?? [:]
        let installed = entries.keys.allSatisfy { event in
            (hooks[event] as? [[String: Any]] ?? []).contains { group in
                (group["hooks"] as? [[String: Any]] ?? []).contains { $0["command"] as? String == command }
            }
        }
        return (installed, isBlocked(object))
    }
    public func install(helper source: URL) throws {
        guard FileManager.default.isExecutableFile(atPath: source.path) else { throw HookInstallerError.missingHelper }
        let baseline = try currentData()
        var object = try read()
        guard !isBlocked(object) else { throw HookInstallerError.policyBlocked }
        try paths.prepare()
        if source.standardizedFileURL != paths.helper.standardizedFileURL {
            let data = try Data(contentsOf: source)
            try data.write(to: paths.helper, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: paths.helper.path)
        }
        var hooks = removingOwned(from: object["hooks"] as? [String: Any] ?? [:])
        for (event, groups) in entries {
            hooks[event] = (hooks[event] as? [[String: Any]] ?? []) + (groups as? [[String: Any]] ?? [])
        }
        object["hooks"] = hooks
        try write(object, baseline: baseline)
    }
    /// Refresh the owned executable after an app update, without rewriting Claude settings.
    @discardableResult public func refreshInstalledHelper(from source: URL) throws -> Bool {
        let state = try inspect()
        guard state.installed, !state.blocked else { return false }
        guard FileManager.default.isExecutableFile(atPath: source.path) else { throw HookInstallerError.missingHelper }
        try paths.prepare()
        if (try? paths.helper.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true { throw HookInstallerError.unsafePath }
        let bytes = try Data(contentsOf: source)
        if (try? Data(contentsOf: paths.helper)) == bytes { return false }
        let staging = paths.helper.deletingLastPathComponent().appendingPathComponent(".bridge-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: staging) }
        try bytes.write(to: staging, options: .withoutOverwriting)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: staging.path)
        guard rename(staging.path, paths.helper.path) == 0 else { throw CocoaError(.fileWriteUnknown) }
        return true
    }
    public func uninstall() throws {
        let baseline = try currentData()
        var object = try read()
        guard object["hooks"] != nil else { return }
        let hooks = removingOwned(from: object["hooks"] as? [String: Any] ?? [:])
        if hooks.isEmpty { object.removeValue(forKey: "hooks") } else { object["hooks"] = hooks }
        try write(object, baseline: baseline)
        // Keep the inert helper so sessions holding an old settings snapshot still exit cleanly.
    }
    private func removingOwned(from hooks: [String: Any]) -> [String: Any] {
        var result = hooks
        for (event, value) in hooks {
            guard let groups = value as? [[String: Any]] else { continue }
            let cleaned = groups.compactMap { group -> [String: Any]? in
                guard let handlers = group["hooks"] as? [[String: Any]] else { return group }
                let remaining = handlers.filter { handler in
                    guard let cmd = handler["command"] as? String else { return true }
                    return !(cmd.contains("dev-island-bridge") && cmd.hasSuffix(" --claude-hook " + Self.owner))
                }
                guard !remaining.isEmpty else { return nil }
                var copy = group; copy["hooks"] = remaining; return copy
            }
            if cleaned.isEmpty { result.removeValue(forKey: event) } else { result[event] = cleaned }
        }
        return result
    }
    private func read() throws -> [String: Any] {
        for url in [configDirectory, settingsURL] {
            if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true { throw HookInstallerError.unsafePath }
        }
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return [:] }
        guard let data = try? Data(contentsOf: settingsURL), let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HookInstallerError.invalidSettings
        }
        if let hooks = object["hooks"], !(hooks is [String: Any]) { throw HookInstallerError.invalidSettings }
        if let hooks = object["hooks"] as? [String: Any] {
            for (_, groups) in hooks { guard groups is [[String: Any]] else { throw HookInstallerError.invalidSettings } }
        }
        return object
    }
    private func isBlocked(_ object: [String: Any]) -> Bool {
        if object["disableAllHooks"] as? Bool == true || object["allowManagedHooksOnly"] as? Bool == true { return true }
        let managed = URL(fileURLWithPath: "/Library/Application Support/ClaudeCode/managed-settings.json")
        if let data = try? Data(contentsOf: managed), let policy = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return policy["allowManagedHooksOnly"] as? Bool == true || policy["disableAllHooks"] as? Bool == true
        }
        return false
    }
    private func currentData() throws -> Data? {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return nil }
        return try Data(contentsOf: settingsURL)
    }
    private func write(_ object: [String: Any], baseline: Data?) throws {
        guard try currentData() == baseline else { throw HookInstallerError.settingsChanged }
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        if let baseline, let existing = try? JSONSerialization.jsonObject(with: baseline) as? [String: Any],
           NSDictionary(dictionary: existing).isEqual(to: object) { return }
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        if FileManager.default.fileExists(atPath: settingsURL.path) {
            let backup = configDirectory.appendingPathComponent("settings.dev-island-backup-\(UUID().uuidString).json")
            try FileManager.default.copyItem(at: settingsURL, to: backup)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
        }
        try data.write(to: settingsURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: settingsURL.path)
    }
}
