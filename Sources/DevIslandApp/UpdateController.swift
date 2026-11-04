import AppKit
import SwiftUI
import Combine
import Sparkle
import DevIslandCore

struct UpdateConfiguration {
    static let feed = "https://akaanuzman.github.io/DevIsland-releases/appcast.xml"
    static func isEnabled(info: [String: Any], arguments: [String]) -> Bool {
        info["DevIslandOfficialRelease"] as? Bool == true &&
        info["CFBundleIdentifier"] as? String == "dev.island.app" &&
        info["SUFeedURL"] as? String == feed &&
        Data(base64Encoded: info["SUPublicEDKey"] as? String ?? "")?.count == 32 &&
        !arguments.contains(where: { ["--demo", "--render-preview", "--verify-storage", "--disable-updates"].contains($0) }) &&
        !arguments.contains(where: { $0.hasSuffix(".xctest") })
    }
}

enum UpdateEvent {
    case available(String), current, finished(Error?)
}
@MainActor protocol UpdateBackend: AnyObject {
    var event: ((UpdateEvent) -> Void)? { get set }
    var automaticChecks: Bool { get set }
    var canCheck: Bool { get }
    var lastCheck: Date? { get }
    func check()
    func channelsChanged()
}

@MainActor final class UpdateController: ObservableObject {
    @Published private(set) var availableVersion: String?
    @Published private(set) var checking = false
    @Published private(set) var lastCheck: Date?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isCurrent = false
    @Published private(set) var enabled = false
    @Published private(set) var automaticChecks: Bool
    @Published private(set) var beta: Bool
    var changed: (() -> Void)?
    private let defaults: UserDefaults
    private var backend: UpdateBackend?
    init(defaults: UserDefaults, backend: UpdateBackend? = nil) {
        self.defaults = defaults
        automaticChecks = defaults.object(forKey: "SUEnableAutomaticChecks") as? Bool ?? true
        beta = defaults.bool(forKey: "updates.beta")
        if let backend { connect(backend) }
    }
    var canCheck: Bool { enabled && !checking && (availableVersion != nil || backend?.canCheck == true) }
    func start(bundle: Bundle = .main, arguments: [String] = CommandLine.arguments) {
        guard backend == nil, UpdateConfiguration.isEnabled(info: bundle.infoDictionary ?? [:], arguments: arguments) else { return }
        connect(SparkleBackend(beta: { [weak self] in self?.beta ?? false }))
    }
    private func connect(_ backend: UpdateBackend) {
        self.backend = backend; enabled = true; automaticChecks = backend.automaticChecks; lastCheck = backend.lastCheck
        backend.event = { [weak self] in self?.receive($0) }
    }
    func setAutomaticChecks(_ value: Bool) {
        automaticChecks = value; defaults.set(value, forKey: "SUEnableAutomaticChecks")
        backend?.automaticChecks = value; changed?()
    }
    func setBeta(_ value: Bool) {
        beta = value; defaults.set(value, forKey: "updates.beta")
        availableVersion = nil; isCurrent = false
        backend?.channelsChanged(); changed?()
    }
    func check() {
        guard canCheck else { return }
        checking = true; isCurrent = false; errorMessage = nil
        NSApp.activate(ignoringOtherApps: true)
        backend?.check(); changed?()
    }
    private func receive(_ event: UpdateEvent) {
        switch event {
        case .available(let version): availableVersion = version; errorMessage = nil; isCurrent = false
        case .current: availableVersion = nil; isCurrent = true; errorMessage = nil
        case .finished(let error):
            checking = false; lastCheck = backend?.lastCheck ?? Date()
            if let error { errorMessage = error.localizedDescription }
        }
        changed?()
    }
}

@MainActor private final class SparkleBackend: NSObject, UpdateBackend, @preconcurrency SPUUpdaterDelegate, @preconcurrency SPUStandardUserDriverDelegate {
    var event: ((UpdateEvent) -> Void)?
    private let beta: () -> Bool
    private var controller: SPUStandardUpdaterController!
    init(beta: @escaping () -> Bool) {
        self.beta = beta; super.init()
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: self)
        controller.startUpdater()
    }
    var automaticChecks: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }
    var canCheck: Bool { controller.updater.canCheckForUpdates }
    var lastCheck: Date? { controller.updater.lastUpdateCheckDate }
    func check() { controller.checkForUpdates(nil) }
    func channelsChanged() { controller.updater.resetUpdateCycleAfterShortDelay() }
    func allowedChannels(for updater: SPUUpdater) -> Set<String> { beta() ? ["beta"] : [] }
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) { event?(.available(item.displayVersionString)) }
    func updaterDidNotFindUpdate(_ updater: SPUUpdater) { event?(.current) }
    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        let ns = error as NSError?
        event?(.finished(ns?.domain == SUSparkleErrorDomain && (ns?.code == Int(SUError.noUpdateError.rawValue) || ns?.code == Int(SUError.installationCanceledError.rawValue)) ? nil : error))
    }
    var supportsGentleScheduledUpdateReminders: Bool { true }
    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool { false }
    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        if !handleShowingUpdate { event?(.available(update.displayVersionString)) }
        else { NSApp.activate(ignoringOtherApps: true) }
    }
}

struct UpdatesSettingsView: View {
    @ObservedObject var updates: UpdateController
    @ObservedObject var model: AppModel
    var body: some View {
        Form {
            LabeledContent(model.t("Yüklü sürüm", "Installed version"), value: "\(BuildInfo.version) (\(BuildInfo.build))")
            LabeledContent(model.t("Son kontrol", "Last checked")) {
                if let date = updates.lastCheck { Text(date, style: .relative) }
                else { Text(model.t("Henüz kontrol edilmedi", "Not checked yet")).foregroundStyle(.secondary) }
            }
            Toggle(model.t("Güncellemeleri otomatik denetle", "Automatically check for updates"), isOn: Binding(get: { updates.automaticChecks }, set: updates.setAutomaticChecks))
            Toggle(model.t("Beta sürümlerini al", "Receive beta updates"), isOn: Binding(get: { updates.beta }, set: updates.setBeta))
            Text(model.t("Saatte bir kontrol edilir. Kurulum için onayın istenir. Beta kapatıldığında bir sonraki uygun kararlı sürüme kadar mevcut sürüm korunur.", "Checks once an hour. Installation requires your approval. Turning beta off keeps your current version until a newer stable release is available."))
                .font(.callout).foregroundStyle(.secondary)
            if let version = updates.availableVersion { Label(model.t("\(version) sürümü hazır", "Version \(version) is available"), systemImage: "arrow.down.circle") }
            if updates.isCurrent { Text(model.t("En güncel sürümü kullanıyorsun.", "You’re up to date.")) }
            if let error = updates.errorMessage { Text(error).foregroundStyle(.secondary).textSelection(.enabled) }
            Button(updates.checking ? model.t("Kontrol ediliyor…", "Checking…") : updates.availableVersion != nil ? model.t("Güncellemeyi aç…", "Open update…") : model.t("Güncellemeleri denetle…", "Check for Updates…"), action: updates.check)
                .disabled(!updates.canCheck)
            if !updates.enabled {
                Text(model.t("Bu yerel geliştirme paketinde uzaktan güncelleme kapalı. İmzalı dağıtım sürümü kurulduğunda etkinleşir.", "Remote updates are disabled in this local development build. Install an official signed release to enable them."))
                    .font(.callout).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }
}
