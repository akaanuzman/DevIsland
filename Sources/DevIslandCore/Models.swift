import Foundation

public enum SessionState: String, Codable, CaseIterable {
    case idle, running, question, plan, permission, completed, failed, disconnected, ended
    public var needsAttention: Bool { [.question, .plan, .permission, .failed].contains(self) }
    public var isWaiting: Bool { [.question, .plan, .permission].contains(self) }
    public var priority: Int {
        switch self {
        case .question: return 0
        case .plan: return 1
        case .permission: return 2
        case .failed: return 3
        case .completed: return 4
        case .running: return 5
        case .idle: return 6
        case .disconnected: return 7
        case .ended: return 8
        }
    }
}

public enum EventKind: String, Codable {
    case sessionStarted, sessionEnded, prompt, toolStarted, toolFinished
    case question, plan, permission, responseFinished, failed, reminder, backgroundStarted, backgroundFinished
}

public struct SourceApplication: Codable, Equatable {
    public var bundleID: String?
    public var processID: Int32?
    public var processStart: UInt64?
    public var tty: String?
    public init(bundleID: String? = nil, processID: Int32? = nil, processStart: UInt64? = nil, tty: String? = nil) {
        self.bundleID = bundleID; self.processID = processID
        self.processStart = processStart; self.tty = tty
    }
}

public struct AgentEvent: Codable, Identifiable {
    public var version = 1
    public var id: UUID
    public var provider = "claude"
    public var sessionID: String
    public var timestamp: Date
    public var kind: EventKind
    public var cwd: String
    public var toolCallID: String?
    public var toolName: String?
    public var agentID: String?
    public var source: SourceApplication
    public var preview: String?
    public var sessionName: ClaudeSessionName?
    public var backgroundCount: Int?
    public var scheduledCount: Int?
    public init(id: UUID = UUID(), sessionID: String, timestamp: Date = Date(), kind: EventKind, cwd: String,
                toolCallID: String? = nil, toolName: String? = nil, agentID: String? = nil,
                source: SourceApplication = .init(), preview: String? = nil,
                backgroundCount: Int? = nil, scheduledCount: Int? = nil, sessionName: ClaudeSessionName? = nil) {
        self.id = id; self.sessionID = sessionID; self.timestamp = timestamp; self.kind = kind; self.cwd = cwd
        self.toolCallID = toolCallID; self.toolName = toolName; self.agentID = agentID; self.source = source
        self.preview = preview; self.sessionName = sessionName; self.backgroundCount = backgroundCount; self.scheduledCount = scheduledCount
    }
    public var withoutPreview: AgentEvent { var copy = self; copy.preview = nil; return copy }
    public var correlationKey: String { "\(agentID ?? "main"):\(toolCallID ?? toolName ?? "notification")" }
}

public struct PendingInteraction: Codable, Equatable {
    public var state: SessionState
    public var started: Date
    public var toolCallID: String?
    public var toolName: String?
    public var agentID: String?
}

public struct AgentSession: Codable, Identifiable {
    public var id: String
    public var cwd: String
    public var state: SessionState = .idle
    public var lastEvent: Date
    public var source: SourceApplication
    public var pending: [String: PendingInteraction] = [:]
    public var retiredCalls: Set<String> = []
    public var turnStarted: Date?
    public var backgroundCount = 0
    public var scheduledCount = 0
    public var label = ""
    public var muted = false
    public var snoozedUntil: Date?
    public var preview: String?
    public var sessionName: ClaudeSessionName?
    public var attentionSince: Date?
    public var reminderSent = false
    public var revalidated = true
    public var project: String { URL(fileURLWithPath: cwd).lastPathComponent }
    public var shortID: String { String(id.prefix(7)) }
    public var title: String { label.isEmpty ? (sessionName?.value ?? project) : label }
    public var isActive: Bool { state != .ended }
    public var withoutPreview: AgentSession { var copy = self; copy.preview = nil; return copy }
    public init(id: String, cwd: String, lastEvent: Date, source: SourceApplication) {
        self.id = id; self.cwd = cwd; self.lastEvent = lastEvent; self.source = source
    }
}

public struct HistoryEntry: Codable, Identifiable {
    public var id: UUID
    public var sessionID: String
    public var timestamp: Date
    public var kind: EventKind
    public var state: SessionState
}

public enum TerminalChoice: String, CaseIterable, Codable {
    case terminal = "com.apple.Terminal"
    case vscode = "com.microsoft.VSCode"
    case cursor = "com.todesktop.230313mzl4w4u92"
    case warp = "dev.warp.Warp-Stable"
    public var title: String {
        switch self { case .terminal: return "Apple Terminal"; case .vscode: return "VS Code"; case .cursor: return "Cursor"; case .warp: return "Warp" }
    }
}

public enum RoutingDecision: Equatable {
    case activate(String), choose([String]), sourceClosed, noApplications
}

public enum RoutingPolicy {
    public static func decide(source: String?, running: [String], preferred: String?) -> RoutingDecision {
        if let source { return running.contains(source) ? .activate(source) : .sourceClosed }
        if running.count == 1 { return .activate(running[0]) }
        if running.isEmpty { return .noApplications }
        if let preferred, running.contains(preferred) { return .activate(preferred) }
        return .choose(running)
    }
}
