import Foundation

public enum ClaudeAdapter {
    /// Deliberately whitelist metadata. Prompts, commands, plans and transcripts never enter the queue.
    public static func decode(_ data: Data, source: SourceApplication = .init(), now: Date = Date(), nameLookup: ((String, String?) -> ClaudeSessionName?)? = nil) throws -> AgentEvent? {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let session = json["session_id"] as? String, !session.isEmpty, session.count <= 256,
              let hook = json["hook_event_name"] as? String else { return nil }
        let tool = json["tool_name"] as? String
        let agent = json["agent_id"] as? String
        let input = json["tool_input"] as? [String: Any] ?? [:]
        var kind: EventKind?
        var preview: String?
        switch hook {
        case "SessionStart": kind = .sessionStarted
        case "SessionEnd": kind = .sessionEnded
        case "UserPromptSubmit": kind = .prompt
        case "PreToolUse":
            if tool == "AskUserQuestion" {
                kind = .question
                preview = (input["questions"] as? [[String: Any]])?.first?["question"] as? String
            } else if tool == "ExitPlanMode" { kind = .plan }
            else { kind = .toolStarted }
        case "PostToolUse", "PostToolUseFailure": kind = .toolFinished
        case "PermissionRequest": kind = .permission
        case "Stop": kind = agent == nil ? .responseFinished : nil
        case "StopFailure": kind = agent == nil ? .failed : nil
        case "SubagentStart": kind = .backgroundStarted
        case "SubagentStop": kind = .backgroundFinished
        case "Notification":
            switch json["notification_type"] as? String {
            case "permission_prompt": kind = .permission
            case "elicitation_dialog", "elicitation_url_dialog", "agent_needs_input": kind = .question
            case "idle_prompt": kind = .reminder
            default: break
            }
        default: break
        }
        guard let kind else { return nil }
        return AgentEvent(sessionID: session, timestamp: now, kind: kind,
                          cwd: json["cwd"] as? String ?? "", toolCallID: json["tool_use_id"] as? String,
                          toolName: tool, agentID: agent, source: source,
                          preview: preview.map { String($0.filter { !$0.isNewline && !$0.isASCIIControl }.prefix(240)) },
                          backgroundCount: (json["background_tasks"] as? [Any])?.count,
                          scheduledCount: (json["session_crons"] as? [Any])?.count,
                          sessionName: (json["session_title"] as? String).flatMap { ClaudeSessionName($0, origin: .custom) }
                            ?? nameLookup?(session, json["transcript_path"] as? String))
    }
}

private extension Character {
    var isASCIIControl: Bool { unicodeScalars.contains { $0.value < 32 || $0.value == 127 } }
}
