import Foundation

public struct SessionLedger: Codable {
    public var sessions: [String: AgentSession] = [:]
    public var history: [HistoryEntry] = []
    public init() {}
    public var sortedSessions: [AgentSession] {
        sessions.values.filter(\.isActive).sorted {
            if $0.state.priority != $1.state.priority { return $0.state.priority < $1.state.priority }
            return $0.lastEvent > $1.lastEvent
        }
    }
    public var persistentCopy: SessionLedger {
        var result = self
        result.sessions = sessions.mapValues(\.withoutPreview)
        return result
    }
    /// Returns a state transition only; duplicate/stale events never produce alerts.
    @discardableResult public mutating func apply(_ event: AgentEvent) -> SessionState? {
        guard event.version == 1, !history.contains(where: { $0.id == event.id }) else { return nil }
        var s = sessions[event.sessionID] ?? AgentSession(id: event.sessionID, cwd: event.cwd, lastEvent: event.timestamp, source: event.source)
        guard event.timestamp >= s.lastEvent else { return nil }
        if s.state == .ended && event.kind != .sessionStarted && event.kind != .prompt { return nil }
        let before = s.state
        let priorAttention = s.attentionSince
        s.lastEvent = event.timestamp; s.revalidated = true
        if !event.cwd.isEmpty { s.cwd = event.cwd }
        if event.source.bundleID != nil { s.source.bundleID = event.source.bundleID }
        if event.source.processID != nil { s.source.processID = event.source.processID; s.source.processStart = event.source.processStart }
        if event.source.tty != nil { s.source.tty = event.source.tty }
        if let name = event.sessionName, s.sessionName?.origin != .custom || name.origin == .custom { s.sessionName = name }
        if let count = event.backgroundCount { s.backgroundCount = count }
        if let count = event.scheduledCount { s.scheduledCount = count }
        switch event.kind {
        case .sessionStarted:
            if [.ended, .disconnected].contains(s.state) { s.state = .idle }
        case .prompt:
            s.turnStarted = event.timestamp; s.pending.removeAll(); s.retiredCalls.removeAll()
            s.preview = nil; s.state = .running
        case .question, .plan, .permission:
            guard !s.retiredCalls.contains(event.correlationKey) else { return nil }
            // The delayed Notification is corroboration, not a second interaction.
            let isFallback = event.toolCallID == nil && event.toolName == nil
            let sameKind = s.pending.values.contains { $0.state == Self.state(for: event.kind) }
            if !(isFallback && (sameKind || !s.pending.isEmpty)) {
                let state = Self.state(for: event.kind)
                // Permission for the question/plan tool must not replace the more useful label.
                if let existing = s.pending[event.correlationKey], existing.state != .permission, state == .permission { break }
                s.pending[event.correlationKey] = PendingInteraction(state: state, started: event.timestamp,
                    toolCallID: event.toolCallID, toolName: event.toolName, agentID: event.agentID)
            }
            if let preview = event.preview { s.preview = preview }
        case .toolStarted:
            if s.pending.isEmpty { s.state = .running; s.preview = nil }
        case .toolFinished:
            let matching = s.pending.filter { key, value in
                guard value.agentID == event.agentID else { return false }
                if let id = event.toolCallID, let pendingID = value.toolCallID { return id == pendingID }
                return value.toolName == event.toolName || key.hasSuffix(":notification")
            }.map(\.key)
            for key in matching { s.pending.removeValue(forKey: key); s.retiredCalls.insert(key) }
            s.retiredCalls.insert(event.correlationKey)
            if s.pending.isEmpty { s.state = .running; s.preview = nil }
        case .responseFinished:
            if s.pending.isEmpty { s.state = .completed; s.preview = nil }
        case .failed:
            s.pending.removeAll(); s.preview = nil; s.state = .failed
        case .sessionEnded:
            s.pending.removeAll(); s.preview = nil; s.state = .ended
        case .backgroundStarted: s.backgroundCount += 1
        case .backgroundFinished: s.backgroundCount = max(0, s.backgroundCount - 1)
        case .reminder: break // Never infer completion or a question from elapsed time.
        }
        if let pending = s.pending.values.min(by: { $0.state.priority < $1.state.priority }) { s.state = pending.state }
        if s.state.needsAttention {
            s.attentionSince = priorAttention ?? event.timestamp
            if before != s.state { s.reminderSent = false }
        } else { s.attentionSince = nil; s.reminderSent = false }
        if s.retiredCalls.count > 4096 { s.retiredCalls = Set(s.retiredCalls.prefix(4096)) }
        sessions[s.id] = s
        history.append(HistoryEntry(id: event.id, sessionID: s.id, timestamp: event.timestamp, kind: event.kind, state: s.state))
        return before != s.state && (s.state.needsAttention || s.state == .completed) ? s.state : nil
    }
    private static func state(for event: EventKind) -> SessionState {
        switch event { case .question: return .question; case .plan: return .plan; default: return .permission }
    }
    public mutating func prune(now: Date = Date(), days: Int = 7) {
        let cutoff = now.addingTimeInterval(-Double(days) * 86400)
        history.removeAll { $0.timestamp < cutoff }
        sessions = sessions.filter { $0.value.isActive || $0.value.lastEvent >= cutoff }
        if history.count > 20000 { history.removeFirst(history.count - 20000) }
    }
}
