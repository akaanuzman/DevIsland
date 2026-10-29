import AppKit
import DevIslandCore

@MainActor final class TerminalRouter {
    private let model: AppModel
    init(model: AppModel) { self.model = model }
    func route(_ session: AgentSession) {
        let candidates = NSWorkspace.shared.runningApplications.compactMap { app -> String? in
            guard let id = app.bundleIdentifier, TerminalChoice(rawValue: id) != nil else { return nil }
            return id
        }
        let running = Array(Set(candidates)).sorted()
        switch RoutingPolicy.decide(source: session.source.bundleID, running: running, preferred: model.preferences.preferredTerminal) {
        case .activate(let id): activate(id, session: session)
        case .sourceClosed:
            message(model.t("Kaynak uygulama kapalı", "Source application is closed"),
                    model.t("Bu Claude oturumu başka bir terminale taşınmadı. Kaynak uygulamayı yeniden açıp oturum durumunu kontrol edebilirsin.", "This Claude session has not moved to another terminal. Reopen its source app and check the session."))
        case .noApplications:
            message(model.t("Açık terminal bulunamadı", "No terminal application is running"),
                    model.t("VS Code, Cursor, Warp veya Apple Terminal’i açıp yeniden dene.", "Open VS Code, Cursor, Warp or Apple Terminal and try again."))
        case .choose(let ids):
            let alert = NSAlert()
            alert.messageText = model.t("Hangi uygulamaya dönelim?", "Which application should open?")
            alert.informativeText = model.t("Bu oturumun kaynak uygulaması belirlenemedi. Seçim yalnızca kaynak belirsiz olduğunda kullanılır.", "The source of this session is unknown. Your preference only applies to unknown sources.")
            for id in ids { alert.addButton(withTitle: TerminalChoice(rawValue: id)?.title ?? id) }
            alert.addButton(withTitle: model.t("Vazgeç", "Cancel"))
            alert.showsSuppressionButton = true
            alert.suppressionButton?.title = model.t("Tercihimi hatırla", "Remember my choice")
            NSApp.activate(ignoringOtherApps: true)
            let index = alert.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
            guard ids.indices.contains(index) else { return }
            if alert.suppressionButton?.state == .on { model.preferences.preferredTerminal = ids[index] }
            activate(ids[index], session: session)
        }
    }
    private func activate(_ id: String, session: AgentSession) {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first else { return }
        app.activate(options: [.activateAllWindows])
        if id == TerminalChoice.terminal.rawValue, let tty = session.source.tty,
           tty.hasPrefix("/dev/"), tty.count < 100, tty.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "/" || $0 == "." || $0 == "_" || $0 == "-" }) {
            // TTY is validated as data, never interpolated from user commands or transcript text.
            let script = """
            tell application "Terminal"
                repeat with w in windows
                    repeat with t in tabs of w
                        if tty of t is "\(tty)" then
                            set selected tab of w to t
                            set index of w to 1
                            activate
                            return true
                        end if
                    end repeat
                end repeat
                return false
            end tell
            """
            var error: NSDictionary?
            let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
            if error != nil {
                model.status = model.t("Terminal açıldı. Sekme seçimi için Automation izni gerekir; Sistem Ayarları > Gizlilik ve Güvenlik > Otomasyon bölümünden açabilirsin.", "Terminal opened. Tab selection requires Automation permission in System Settings > Privacy & Security > Automation.")
            } else if result?.booleanValue != true {
                model.status = model.t("Terminal açıldı; eşleşen sekme artık bulunamıyor.", "Terminal opened; the matching tab is no longer available.")
            }
        }
    }
    private func message(_ title: String, _ detail: String) {
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = detail
        alert.addButton(withTitle: model.t("Tamam", "OK")); NSApp.activate(ignoringOtherApps: true); alert.runModal()
    }
}
