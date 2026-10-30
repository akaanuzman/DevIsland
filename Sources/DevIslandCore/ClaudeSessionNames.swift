import Foundation

public struct ClaudeSessionName: Codable, Equatable {
    public enum Origin: String, Codable { case custom, automatic }
    public let value: String
    public let origin: Origin
    public init?(_ raw: String, origin: Origin) {
        let cleaned = raw.unicodeScalars.map { scalar -> String in
            if CharacterSet.controlCharacters.contains(scalar) || scalar.properties.generalCategory == .format { return " " }
            return String(scalar)
        }.joined().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !cleaned.isEmpty else { return nil }
        value = String(cleaned.prefix(200)); self.origin = origin
    }
}

/// Reads only allowlisted naming metadata. Never returns conversation text or writes to Claude's files.
/// Registry/transcript formats are a best-effort compatibility fallback; session_title is the hook API.
public enum ClaudeSessionNames {
    public static var defaultDirectory: URL {
        if let path = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"], !path.isEmpty { return URL(fileURLWithPath: path) }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    }
    private struct Registration { let name: ClaudeSessionName?; let cwd: String?; let modified: Date }
    private static func validID(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 256 && id.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95 }
    }
    private static func regular(_ url: URL, inside root: URL, maximum: Int? = nil) -> Bool {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        let base = root.resolvingSymlinksInPath().standardizedFileURL.path + "/"
        guard path.hasPrefix(base), let attrs = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              attrs.isRegularFile == true, attrs.isSymbolicLink != true else { return false }
        return maximum.map { (attrs.fileSize ?? Int.max) <= $0 } ?? true
    }
    private static func registrations(ids: Set<String>, directory: URL, processID: Int32? = nil) -> [String: Registration] {
        let root = directory.appendingPathComponent("sessions")
        let files: [URL]
        if let processID { files = [root.appendingPathComponent("\(processID).json")] }
        else { files = Array(((try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []).filter { $0.pathExtension == "json" }.prefix(1024)) }
        var result: [String: Registration] = [:]
        for file in files {
            guard regular(file, inside: root, maximum: 32768), let data = try? Data(contentsOf: file),
                  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let id = json["sessionId"] as? String, ids.contains(id) else { continue }
            let source = json["nameSource"] as? String
            // Folder-derived registry defaults are not the terminal's session name.
            let name = source == "derived" ? nil : (json["name"] as? String).flatMap { ClaudeSessionName($0, origin: source == "user" ? .custom : .automatic) }
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if let current = result[id], current.modified > modified { continue }
            result[id] = Registration(name: name, cwd: json["cwd"] as? String, modified: modified)
        }
        return result
    }
    public static func resolve(sessionID: String, transcriptPath: String?, configDirectory: URL = defaultDirectory,
                               processID: Int32? = nil) -> ClaudeSessionName? {
        guard validID(sessionID) else { return nil }
        var registered = registrations(ids: [sessionID], directory: configDirectory, processID: processID)[sessionID]
        if registered == nil && processID != nil { registered = registrations(ids: [sessionID], directory: configDirectory)[sessionID] }
        let record = transcriptPath.flatMap { transcriptName(at: URL(fileURLWithPath: $0), sessionID: sessionID, configDirectory: configDirectory) }
        if record?.origin == .custom { return record }
        return registered?.name ?? record
    }
    public static func lookup(sessions: [AgentSession], configDirectory: URL = defaultDirectory) -> [String: ClaudeSessionName] {
        let ids = Set(sessions.map(\.id).filter(validID))
        let registered = registrations(ids: ids, directory: configDirectory)
        var result: [String: ClaudeSessionName] = [:]
        for session in sessions where ids.contains(session.id) {
            let cwd = registered[session.id]?.cwd ?? session.cwd
            let encoded = cwd.utf8.map { byte -> String in
                (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte) ? String(UnicodeScalar(byte)) : "-"
            }.joined()
            let path = configDirectory.appendingPathComponent("projects").appendingPathComponent(encoded).appendingPathComponent(session.id + ".jsonl")
            let record = transcriptName(at: path, sessionID: session.id, configDirectory: configDirectory)
            result[session.id] = record?.origin == .custom ? record : (registered[session.id]?.name ?? record)
        }
        return result
    }
    public static func transcriptName(at url: URL, sessionID: String, configDirectory: URL = defaultDirectory) -> ClaudeSessionName? {
        let root = configDirectory.appendingPathComponent("projects")
        guard validID(sessionID), url.lastPathComponent == sessionID + ".jsonl", regular(url, inside: root),
              let file = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? file.close() }
        // At most 288 KiB, irrespective of transcript size. Partial/oversized lines are ignored.
        guard let size = try? file.seekToEnd() else { return nil }
        let offset = size > 262144 ? size - 262144 : 0
        var regions: [Data] = []
        if offset > 0 {
            try? file.seek(toOffset: 0)
            if let head = try? file.read(upToCount: 32768), let end = head.lastIndex(of: 10) { regions.append(head.prefix(through: end)) }
        }
        try? file.seek(toOffset: offset)
        if let tail = try? file.read(upToCount: 262144) {
            if offset == 0 { regions.append(tail) }
            else if let boundary = tail.firstIndex(of: 10) { regions.append(tail.suffix(from: tail.index(after: boundary))) }
        }
        var custom: ClaudeSessionName?, automatic: ClaudeSessionName?
        for data in regions {
            for line in data.split(separator: 10) where line.count <= 16384 {
                guard let prefix = String(data: line.prefix(512), encoding: .utf8),
                      prefix.contains("\"custom-title\"") || prefix.contains("\"agent-name\""),
                      let json = (try? JSONSerialization.jsonObject(with: Data(line))) as? [String: Any],
                      json["sessionId"] as? String == sessionID else { continue }
                if json["type"] as? String == "custom-title", let value = json["customTitle"] as? String {
                    custom = ClaudeSessionName(value, origin: .custom) ?? custom
                } else if json["type"] as? String == "agent-name", let value = json["agentName"] as? String {
                    automatic = ClaudeSessionName(value, origin: .automatic) ?? automatic
                }
            }
        }
        return custom ?? automatic
    }
}
