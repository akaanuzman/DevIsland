import Foundation
import CDevIsland
import Darwin

public struct AppPaths {
    public var root: URL
    public var queue: URL { root.appendingPathComponent("queue", isDirectory: true) }
    public var helper: URL { root.appendingPathComponent("bin/dev-island-bridge") }
    public var socket: String { root.appendingPathComponent("events.sock").path }
    public init(root: URL? = nil) {
        self.root = root ?? ProcessInfo.processInfo.environment["DEV_ISLAND_HOME"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/DevIsland", isDirectory: true)
    }
    public func prepare() throws {
        for url in [root, queue, helper.deletingLastPathComponent()] {
            if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true { throw TransportError.unsafeDirectory }
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        }
    }
}

public enum TransportError: Error { case unsafeDirectory, oversized }

public enum EventQueue {
    public static let maxEntries = 1000
    public static func enqueue(_ event: AgentEvent, paths: AppPaths) throws {
        try paths.prepare()
        let data = try JSONEncoder().encode(event.withoutPreview)
        guard data.count < 32768 else { throw TransportError.oversized }
        let destination = paths.queue.appendingPathComponent(event.id.uuidString + ".json")
        try data.write(to: destination, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        let files = try pending(paths: paths)
        if files.count > maxEntries { for url in files.prefix(files.count - maxEntries) { try? FileManager.default.removeItem(at: url) } }
        let message = try JSONEncoder().encode(event)
        _ = message.withUnsafeBytes { di_socket_send(paths.socket, $0.baseAddress, message.count) }
    }
    public static func pending(paths: AppPaths) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: paths.queue, includingPropertiesForKeys: [.contentModificationDateKey, .isSymbolicLinkKey])
            .filter { $0.pathExtension == "json" }
            .sorted {
                let lhs = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhs = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhs == rhs ? $0.lastPathComponent < $1.lastPathComponent : lhs < rhs
            }
    }
    public static func read(_ url: URL) throws -> AgentEvent {
        let attrs = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
        guard attrs.isSymbolicLink != true, (attrs.fileSize ?? 0) <= 32768 else { throw TransportError.oversized }
        return try JSONDecoder().decode(AgentEvent.self, from: Data(contentsOf: url))
    }
    public static func acknowledge(_ event: AgentEvent, paths: AppPaths) {
        try? FileManager.default.removeItem(at: paths.queue.appendingPathComponent(event.id.uuidString + ".json"))
    }
}

public struct ProcessIdentity {
    public var pid: Int32
    public var parent: Int32
    public var start: UInt64
    public var path: String
    public var tty: String?
    public static func read(_ pid: Int32) -> ProcessIdentity? {
        var parent: Int32 = 0, start: UInt64 = 0
        var path = [CChar](repeating: 0, count: 4096), tty = [CChar](repeating: 0, count: 1024)
        guard di_process(pid, &parent, &start, &path, 4096, &tty, 1024) == 1 else { return nil }
        let ttyString = String(cString: tty)
        return .init(pid: pid, parent: parent, start: start, path: String(cString: path), tty: ttyString.isEmpty ? nil : ttyString)
    }
    public static func isAlive(pid: Int32, start: UInt64) -> Bool? {
        if let info = read(pid) { return info.start == start }
        if kill(pid, 0) == -1 && errno == ESRCH { return false }
        return nil // Access denied must not look like process death.
    }
    public static func discoverSource() -> SourceApplication {
        var pid = getppid(), result = SourceApplication()
        var visited = Set<Int32>()
        for _ in 0..<24 {
            guard pid > 1, visited.insert(pid).inserted, let info = read(pid) else { break }
            if result.tty == nil { result.tty = info.tty }
            let executable = URL(fileURLWithPath: info.path).lastPathComponent.lowercased()
            if result.processID == nil && (executable == "claude" || info.path.contains("/claude/")) {
                result.processID = pid; result.processStart = info.start
            }
            for terminal in TerminalChoice.allCases {
                let needle: String
                switch terminal {
                case .terminal: needle = "/Terminal.app/"
                case .vscode: needle = "/Visual Studio Code.app/"
                case .cursor: needle = "/Cursor.app/"
                case .warp: needle = "/Warp.app/"
                }
                if info.path.contains(needle), result.bundleID == nil { result.bundleID = terminal.rawValue }
            }
            pid = info.parent
        }
        if result.bundleID == nil {
            switch ProcessInfo.processInfo.environment["TERM_PROGRAM"] {
            case "Apple_Terminal": result.bundleID = TerminalChoice.terminal.rawValue
            case "WarpTerminal": result.bundleID = TerminalChoice.warp.rawValue
            default: break // vscode alone cannot distinguish VS Code from Cursor.
            }
        }
        return result
    }
}
