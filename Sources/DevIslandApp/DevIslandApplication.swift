import AppKit
import SwiftUI
import Combine
import DevIslandCore
import ImageIO

func launchTrace(_ stage: String) {
    if ProcessInfo.processInfo.environment["DEV_ISLAND_TRACE"] == "1" {
        FileHandle.standardError.write(Data(("DevIsland launch: " + stage + "\n").utf8))
    }
}

@main struct DevIslandApplication {
    @MainActor static func main() {
        if let index = CommandLine.arguments.firstIndex(of: "--render-preview"), CommandLine.arguments.indices.contains(index + 1) {
            do {
                let destination = URL(fileURLWithPath: CommandLine.arguments[index + 1])
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                let model = AppModel()
                model.preferences.language = "tr"
                model.ledger = SessionLedger()
                for (id, project, kind) in [("preview-cookify", "Cookify", EventKind.question), ("preview-nailoria", "Nailoria", .plan), ("preview-landing", "Landing", .toolStarted)] {
                    model.ledger.apply(AgentEvent(sessionID: id, kind: kind, cwd: "/Projects/" + project, toolCallID: id,
                                                 source: .init(bundleID: TerminalChoice.cursor.rawValue)))
                }
                model.integrationInstalled = true
                model.preferences = Preferences(); model.preferences.language = "tr"
                for theme in [ThemeMode.light, .dark] {
                    model.preferences.theme = theme; model.preferences.surface = .liquid
                    let scheme: ColorScheme = theme == .light ? .light : .dark
                    for page in SettingsPage.allCases {
                        let height: CGFloat = page == .appearance ? 1020 : page == .notifications ? 900 : 700
                        try nativeSnapshot(SettingsView(model: model, initialPage: page).frame(width: 920, height: height).environment(\.colorScheme, scheme), dark: theme == .dark, to: destination.appendingPathComponent("settings-\(theme.rawValue)-\(page.rawValue).png"))
                    }
                    for surface in SurfaceMaterial.allCases {
                        model.preferences.surface = surface
                        let name = theme.rawValue + "-" + surface.rawValue
                        let presentation = IslandPresentation(); presentation.mode = .expanded; presentation.bodyMode = .expanded
                        let height = 36 + PanelSizing.height(of: SessionTrayView(model: model, close: {}).appTheme(model.preferences), width: 460, maximum: 520)
                        presentation.geometry = .init(width: 460, height: height, radius: 26, contentOpacity: 1)
                        try snapshot(IslandView(model: model, presentation: presentation).frame(width: 460, height: height).environment(\.colorScheme, scheme), to: destination.appendingPathComponent("island-\(name).png"))
                        let trayHeight = PanelSizing.height(of: MascotTrayView(model: model, close: {}), width: 400, maximum: 580)
                        try snapshot(MascotTrayView(model: model, close: {}).frame(width: 400, height: trayHeight).environment(\.colorScheme, scheme), to: destination.appendingPathComponent("companion-\(name).png"))
                    }
                    let compact = IslandPresentation()
                    try snapshot(IslandView(model: model, presentation: compact).frame(width: 180, height: 36).environment(\.colorScheme, scheme), to: destination.appendingPathComponent("compact-\(theme.rawValue).png"))
                }
                model.preferences.surface = .liquid
                for (kind, hex) in [(MascotKind.cat, "7EB4DA"), (.robot, "9B87C8")] {
                    model.preferences.mascot = kind
                    model.preferences.mascotColors[kind.rawValue] = .init(mode: .custom, hex: hex)
                    try nativeSnapshot(SettingsView(model: model, initialPage: .appearance).frame(width: 920, height: 1020), dark: true, to: destination.appendingPathComponent("custom-\(kind.rawValue)-settings.png"))
                    let p = IslandPresentation(); p.mode = .expanded; p.bodyMode = .expanded
                    let height = 36 + PanelSizing.height(of: SessionTrayView(model: model, close: {}).appTheme(model.preferences), width: 460, maximum: 520)
                    p.geometry = .init(width: 460, height: height, radius: 26, contentOpacity: 1)
                    try snapshot(IslandView(model: model, presentation: p).frame(width: 460, height: height), to: destination.appendingPathComponent("custom-\(kind.rawValue)-island.png"))
                }
                for kind in MascotKind.allCases {
                    try snapshot(ClawdContactSheet(kind: kind).frame(width: 640, height: 320).background(Color(hex: "F5F5F5")), to: destination.appendingPathComponent("\(kind.rawValue)-states.png"))
                    for pose in ClawdPose.allCases { try renderGIF(kind: kind, pose: pose, to: destination.appendingPathComponent("\(kind.rawValue)-\(pose.rawValue).gif")) }
                }
                try snapshot(MascotColorSheet().background(Color(hex: "F5F5F5")), to: destination.appendingPathComponent("mascot-colors.png"))
                try snapshot(DevIslandMark(size: 256).padding(32).background(Color(hex: "F5F5F5")), to: destination.appendingPathComponent("monogram.png"))
                print("Rendered 12 native settings pages, 12 material panels, 2 compact islands, 4 custom character previews, 3 pose sheets, color sheet, monogram and 24 mascot animation samples.")
                return
            } catch { FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8)); exit(1) }
        }
        if CommandLine.arguments.contains("--verify-storage") {
            do {
                let root = FileManager.default.temporaryDirectory.appendingPathComponent("dev-island-storage-" + UUID().uuidString)
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: root) }
                let repository = try SessionRepository(root: root)
                var ledger = SessionLedger()
                ledger.apply(AgentEvent(sessionID: "storage-smoke", kind: .question, cwd: "/Test", toolCallID: "q", preview: "DO-NOT-PERSIST"))
                try repository.save(ledger)
                let secondRepository = try SessionRepository(root: root)
                let restored = try secondRepository.load()
                guard restored.sessions["storage-smoke"]?.state == .question,
                      restored.sessions["storage-smoke"]?.preview == nil,
                      restored.sessions["storage-smoke"]?.pending.count == 1,
                      restored.history.count == 1 else { throw CocoaError(.fileReadCorruptFile) }
                print("{\"passed\":true,\"swiftDataRoundTrip\":true,\"waitingPreserved\":true,\"previewPersisted\":false}")
                return
            } catch {
                FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8)); exit(1)
            }
        }
        launchTrace("NSApplication")
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        launchTrace("accessory policy")
        app.setActivationPolicy(.accessory)
        launchTrace("run loop")
        withExtendedLifetime(delegate) { app.run() }
    }
    @MainActor private static func nativeSnapshot<V: View>(_ view: V, dark: Bool, to destination: URL) throws {
        let controller = NSHostingController(rootView: view)
        let size = controller.sizeThatFits(in: CGSize(width: 920, height: 2000))
        let window = NSPanel(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let host = PanelSizing.host(view)
        window.contentView = host; host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded(); window.displayIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw CocoaError(.fileWriteUnknown) }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: destination); window.close()
    }
    @MainActor private static func snapshot<V: View>(_ view: V, to destination: URL) throws {
        let renderer = ImageRenderer(content: view.environment(\.snapshotPreview, true))
        renderer.scale = 2
        guard let image = renderer.cgImage, let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: destination)
    }
    @MainActor private static func renderGIF(kind: MascotKind, pose: ClawdPose, to destination: URL) throws {
        guard let gif = CGImageDestinationCreateWithURL(destination as CFURL, "com.compuserve.gif" as CFString, 16, nil) else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<16 {
            let view = ClawdView(pose: pose, kind: kind, size: 160, active: false, sampleTime: Double(frame) * (pose == .idle ? 0.4 : 0.1))
                .padding(16).background(Color(hex: "F5F5F5")).environment(\.snapshotPreview, true)
            let renderer = ImageRenderer(content: view); renderer.scale = 2
            guard let image = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
            CGImageDestinationAddImage(gif, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: pose == .idle ? 0.4 : 0.1]] as CFDictionary)
        }
        guard CGImageDestinationFinalize(gif) else { throw CocoaError(.fileWriteUnknown) }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var model: AppModel!
    private var island: IslandController!
    private var mascot: MascotController!
    private var router: TerminalRouter!
    private var shortcut: ShortcutController!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var subscriptions = Set<AnyCancellable>()
    func applicationDidFinishLaunching(_ notification: Notification) {
        launchTrace("did finish launching")
        if let identifier = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: identifier).contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSApp.terminate(nil); return
        }
        launchTrace("model")
        model = AppModel()
        ThemeCoordinator.shared.update(model.preferences)
        launchTrace("island")
        island = IslandController(model: model)
        mascot = MascotController(model: model)
        router = TerminalRouter(model: model)
        shortcut = ShortcutController()
        model.showSettings = { [weak self] in self?.openSettings() }
        model.showSessions = { [weak self] in self?.showActivity() }
        model.presentAlert = { [weak self] in self?.island.alert($0) }
        model.routeSession = { [weak self] in self?.router.route($0) }
        model.settingsChanged = { [weak self] in
            guard let self else { return }
            ThemeCoordinator.shared.update(self.model.preferences)
            self.island.layout(); self.mascot.layout(); self.refreshMenu(); self.updateShortcut()
            if let window = self.settingsWindow { applyAppearance(self.model.preferences, to: window) }
        }
        shortcut.action = { [weak self] in
            guard let self else { return }
            if self.model.preferences.showsIsland { self.island.toggle() } else { self.mascot.toggleTray() }
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let iconRenderer = ImageRenderer(content: DevIslandMark(size: 18, monochrome: true).environment(\.colorScheme, .light))
        iconRenderer.scale = 2
        statusItem.button?.image = iconRenderer.nsImage
        statusItem.button?.image?.isTemplate = true
        model.$ledger.receive(on: RunLoop.main).sink { [weak self] _ in self?.refreshMenu() }.store(in: &subscriptions)
        launchTrace("menu")
        refreshMenu(); updateShortcut()
        launchTrace("services")
        model.start()
        mascot.layout()
        launchTrace("settings")
        if !model.defaults.bool(forKey: "onboarded") || CommandLine.arguments.contains("--show-settings") { openSettings() }
        if CommandLine.arguments.contains("--demo") { island.expand() }
    }
    func applicationWillTerminate(_ notification: Notification) { model?.stop() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { openSettings(); return true }
    private func updateShortcut() {
        guard shortcut != nil else { return }
        if !shortcut.register(key: model.preferences.shortcutKey, modifiers: model.preferences.shortcutModifiers) {
            model.status = model.t("Bu kısayol başka bir uygulama tarafından kullanılıyor. Görünüm’den farklı bir kısayol seç.", "This shortcut is in use. Choose another in Appearance.")
        }
    }
    private func refreshMenu() {
        guard statusItem != nil else { return }
        let menu = NSMenu()
        let summary = NSMenuItem(title: model.t("\(model.waitingCount) bekleyen · \(model.runningCount) çalışan", "\(model.waitingCount) need you · \(model.runningCount) working"), action: nil, keyEquivalent: "")
        summary.isEnabled = false; menu.addItem(summary); menu.addItem(.separator())
        item(model.t("Oturumları göster", "Show sessions"), #selector(showIsland), menu: menu)
        item(model.t("Ayarlar…", "Settings…"), #selector(settingsAction), menu: menu, key: ",")
        let quiet = item(model.t("Sessiz mod", "Quiet mode"), #selector(toggleQuiet), menu: menu)
        quiet.state = model.preferences.quiet ? .on : .off
        item(model.preferences.showsMascot ? model.t("Maskotu gizle", "Hide mascot") : model.t("Maskotu göster", "Show mascot"), #selector(toggleMascot), menu: menu)
        menu.addItem(.separator())
        item(model.t("Köprü testi gönder", "Send bridge test"), #selector(testBridge), menu: menu)
        menu.addItem(.separator())
        item(model.t("Dev Island’dan çık", "Quit Dev Island"), #selector(quit), menu: menu, key: "q")
        statusItem.menu = menu
        statusItem.button?.toolTip = "Dev Island · \(model.waitingCount)"
    }
    @discardableResult private func item(_ title: String, _ selector: Selector, menu: NSMenu, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key); item.target = self; menu.addItem(item); return item
    }
    private func showActivity() { if model.preferences.showsIsland { island.expand() } else { mascot.toggleTray() } }
    @objc private func showIsland() { showActivity() }
    @objc private func settingsAction() { openSettings() }
    @objc private func toggleQuiet() { model.preferences.quiet.toggle() }
    @objc private func toggleMascot() {
        var prefs = model.preferences
        if prefs.showsMascot { prefs.mascotHidden = true }
        else { prefs.mascotHidden = false; if prefs.companionVisibility == .island { prefs.companionVisibility = .both } }
        model.preferences = prefs
    }
    @objc private func testBridge() { model.testBridge() }
    @objc private func quit() { NSApp.terminate(nil) }
    private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 920, height: 780), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Dev Island"
            window.delegate = self
            window.titlebarAppearsTransparent = true
            window.backgroundColor = .windowBackgroundColor; window.isOpaque = true
            window.contentView = NSHostingView(rootView: SettingsView(model: model))
            window.minSize = NSSize(width: 800, height: 620)
            window.isReleasedWhenClosed = false; window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        model.settingsVisible = true
        if let window = settingsWindow { applyAppearance(model.preferences, to: window) }
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) { model.settingsVisible = false }
    func windowDidMiniaturize(_ notification: Notification) { model.settingsVisible = false }
    func windowDidDeminiaturize(_ notification: Notification) { model.settingsVisible = true }
}
