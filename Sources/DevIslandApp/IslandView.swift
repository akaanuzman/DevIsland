import SwiftUI
import AppKit
import DevIslandCore

let islandOrange = Color.adaptive(light: "A74D28", dark: "E69A75")
private struct SnapshotPreviewKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var snapshotPreview: Bool {
        get { self[SnapshotPreviewKey.self] }
        set { self[SnapshotPreviewKey.self] = newValue }
    }
}
struct SnapshotScroll<Content: View>: View {
    @Environment(\.snapshotPreview) private var snapshot
    @ViewBuilder var content: () -> Content
    var body: some View {
        if snapshot { content().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).clipped() }
        else { ScrollView { content() } }
    }
}
extension SessionState {
    var tint: Color {
        switch self {
        case .question, .plan, .permission: return islandOrange
        case .running: return .adaptive(light: "526B8C", dark: "A5BEDD")
        case .completed: return .adaptive(light: "357344", dark: "99CBA2")
        case .failed: return .adaptive(light: "AF3933", dark: "F6A39B")
        default: return .adaptive(light: "626262", dark: "B8B8B8")
        }
    }
    var symbol: String {
        switch self {
        case .question: return "questionmark.bubble.fill"
        case .plan: return "list.bullet.clipboard.fill"
        case .permission: return "lock.shield.fill"
        case .running: return "circle.dotted"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .disconnected: return "bolt.slash.fill"
        case .ended: return "xmark.circle"
        case .idle: return "circle"
        }
    }
}
@MainActor final class IslandPresentation: ObservableObject {
    @Published var mode: IslandMode = .compact
    @Published var bodyMode: IslandMode = .compact
    @Published var geometry = IslandGeometry(width: 180, height: 36, radius: 18)
    @Published var sessionID: String?
    @Published var safeTop: CGFloat = 36
    @Published var notchWidth: CGFloat = 0
    @Published var visible = false
    var hover: ((Bool) -> Void)?
    var toggle: (() -> Void)?
    var collapse: (() -> Void)?
}
struct IslandView: View {
    @Environment(\.colorScheme) private var systemScheme
    private var colors: ThemeColors { ThemeColors(dark: (model.preferences.colorScheme ?? systemScheme) == .dark, accentHex: model.preferences.accentHex) }
    @ObservedObject var model: AppModel
    @ObservedObject var presentation: IslandPresentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.snapshotPreview) private var snapshot
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                CompanionView(model: model, size: 30, active: presentation.visible)
                Spacer(minLength: presentation.notchWidth + 8)
                HStack(spacing: 5) {
                    Text("\(model.waitingCount > 0 ? model.waitingCount : model.runningCount)")
                        .font(.system(size: 12, weight: .medium)).monospacedDigit()
                    Image(systemName: model.waitingCount > 0 ? "bell.badge.fill" : "circle.dotted")
                        .font(.system(size: 11))
                }.foregroundStyle(Color(colors.accent))
            }
            .padding(.horizontal, 18).frame(height: presentation.safeTop)
            .contentShape(Rectangle()).onTapGesture { presentation.toggle?() }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(model.t("Dev Island. \(model.waitingCount) bekleyen, \(model.runningCount) çalışan oturum.", "Dev Island. \(model.waitingCount) need attention, \(model.runningCount) working."))
            .accessibilityAddTraits(.isButton).accessibilityAction { presentation.toggle?() }

            Group {
                switch presentation.bodyMode {
                case .compact: EmptyView()
                case .alert: IslandAlertBody(model: model, sessionID: presentation.sessionID, close: { presentation.collapse?() }, showAll: { presentation.toggle?() })
                case .expanded: SessionTrayView(model: model, close: { presentation.collapse?() })
                }
            }
            .frame(width: presentation.geometry.width, height: max(0, presentation.geometry.height - presentation.safeTop), alignment: .top)
            .allowsHitTesting(presentation.mode != .compact)
            .accessibilityHidden(presentation.mode == .compact)
            .opacity(presentation.geometry.contentOpacity)
            .offset(y: reduceMotion ? 0 : (1 - presentation.geometry.contentOpacity) * -6)
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .islandSurface(model.preferences, radius: presentation.geometry.radius)
        .appTheme(model.preferences)
        .onHover { presentation.hover?($0) }
        .onExitCommand { presentation.collapse?() }
    }
}
struct IslandAlertBody: View {
    @Environment(\.themeColors) private var colors
    @ObservedObject var model: AppModel
    var sessionID: String?
    var close: () -> Void
    var showAll: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let id = sessionID, let session = model.ledger.sessions[id] {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: session.state.symbol).foregroundStyle(session.state.tint).font(.title3)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.title(session.state)).font(.system(size: 14, weight: .semibold))
                        Text(model.preferences.hideProjects ? "Claude Code" : session.title).font(.system(size: 12)).foregroundStyle(Color(colors.secondary)).lineLimit(1)
                    }
                    Spacer()
                    Button(action: close) { Image(systemName: "xmark").font(.system(size: 10, weight: .bold)) }
                        .buttonStyle(.plain).accessibilityLabel(model.t("Bildirimi kapat", "Dismiss notification"))
                }
                HStack {
                    Button(model.t("Uygulamaya dön", "Return to app")) { model.routeSession?(session) }.buttonStyle(.bordered)
                    Spacer()
                    Button(model.t("Tüm oturumlar", "All sessions"), action: showAll).buttonStyle(.plain)
                }.font(.system(size: 12))
            }
        }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 12)
    }
}
struct SessionTrayView: View {
    @Environment(\.themeColors) private var colors
    @ObservedObject var model: AppModel
    var close: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(model.t("Oturumlar", "Sessions")).font(.system(size: 12, weight: .semibold))
                Text("\(model.sessions.count)").font(.system(size: 11)).foregroundStyle(Color(colors.secondary))
                Spacer()
                Button(action: close) { Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)) }
                    .buttonStyle(.plain).foregroundStyle(Color(colors.secondary)).accessibilityLabel(model.t("Daralt", "Collapse"))
            }.fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .vertical) {
                rows.fixedSize(horizontal: false, vertical: true)
                SnapshotScroll { rows }
            }
            Divider()
            HStack {
                Button { model.preferences.quiet.toggle() } label: { Label(model.t("Sessiz", "Quiet"), systemImage: model.preferences.quiet ? "bell.slash.fill" : "bell") }
                Spacer()
                Button { model.showSettings?() } label: { Label(model.t("Ayarlar", "Settings"), systemImage: "gearshape") }
            }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Color(colors.secondary))
                .fixedSize(horizontal: false, vertical: true)
        }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 12)
    }
    private var rows: some View {
        VStack(spacing: 0) {
            if model.sessions.isEmpty {
                Text(model.t("Aktif Claude oturumu yok.", "No active Claude sessions."))
                    .font(.system(size: 12)).foregroundStyle(Color(colors.secondary))
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
            } else {
                ForEach(model.sessions) { session in
                    SessionRow(model: model, session: session, compact: true)
                    if session.id != model.sessions.last?.id { Divider() }
                }
            }
        }
    }
}
struct SessionRow: View {
    @ObservedObject var model: AppModel
    let session: AgentSession
    var compact = false
    @State private var hovered = false
    @Environment(\.themeColors) private var colors
    @State private var editingLabel = false
    @State private var label = ""
    @Environment(\.snapshotPreview) private var snapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: session.state.symbol).font(.system(size: 15)).foregroundStyle(session.state.tint)
                    .frame(width: 22, height: 24)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.preferences.hideProjects ? "Claude Code" : session.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                        if session.muted { Image(systemName: "bell.slash.fill").font(.caption2).foregroundStyle(Color(colors.secondary)) }
                        if let until = session.snoozedUntil, until > Date() { Image(systemName: "clock.badge").font(.caption2).foregroundStyle(Color(colors.secondary)) }
                    }
                    Text(model.title(session.state)).font(.system(size: 11)).foregroundStyle(session.state.tint)
                    if !compact {
                        HStack(spacing: 5) {
                            Text(session.source.bundleID.flatMap(TerminalChoice.init(rawValue:))?.title ?? model.t("Kaynak bilinmiyor", "Unknown source"))
                            Text("· \(session.shortID)")
                            Text(session.attentionSince ?? session.lastEvent, style: .relative)
                        }.font(.system(size: 10)).foregroundStyle(Color(colors.secondary)).lineLimit(1)
                        if !session.revalidated {
                            Text(model.t("Kaydedilmiş durum · yeni olayla doğrulanacak", "Saved state · awaiting verification")).font(.caption2).foregroundStyle(Color(colors.secondary))
                        }
                        if session.backgroundCount > 0 || session.scheduledCount > 0 {
                            Text(model.t("Arka plan: \(session.backgroundCount) · Zamanlanmış: \(session.scheduledCount)", "Background: \(session.backgroundCount) · Scheduled: \(session.scheduledCount)"))
                                .font(.caption2).foregroundStyle(Color(colors.secondary))
                        }
                    }
                }
                Spacer(minLength: 4)
                Button { model.routeSession?(session) } label: { Image(systemName: "arrow.up.forward").font(.system(size: 12, weight: .semibold)) }
                    .buttonStyle(.plain).foregroundStyle(Color(colors.accent)).padding(5).help(model.t("Uygulamaya dön", "Return to app")).accessibilityLabel(model.t("Uygulamaya dön", "Return to app"))
                if snapshot {
                    Image(systemName: "ellipsis").foregroundStyle(Color(colors.secondary)).frame(width: 16)
                } else { Menu {
                    Button(model.t("Uygulamaya dön", "Return to app")) { model.routeSession?(session) }
                    Button(model.t("5 dakika ertele", "Snooze for 5 minutes")) { model.mutateSession(session.id) { $0.snoozedUntil = Date().addingTimeInterval(300) } }
                    Button(session.muted ? model.t("Bildirimleri aç", "Unmute") : model.t("Bu oturumu sustur", "Mute this session")) { model.mutateSession(session.id) { $0.muted.toggle() } }
                    Button(model.t("Etiketi değiştir", "Edit label")) { label = session.label; editingLabel = true }
                    if session.id.hasPrefix("diagnostic-") || session.id.hasPrefix("demo-") || session.state == .disconnected {
                        Divider()
                        Button(model.t("Listeden kaldır", "Remove from list")) { model.mutateSession(session.id) { $0.state = .ended; $0.pending.removeAll() } }
                    }
                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 16)
                    .accessibilityLabel(model.t("Oturum eylemleri", "Session actions"))
                }
            }
            if model.preferences.showPreview, !model.preferences.hideProjects, let preview = session.preview {
                Text(preview).font(.system(size: 12)).foregroundStyle(Color(colors.secondary)).lineLimit(3)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, compact ? 10 : 12)
        .background(Color(colors.primary).opacity(hovered ? 0.055 : 0), in: RoundedRectangle(cornerRadius: 6))
        .onHover { hovered = $0 }
        .alert(model.t("Oturum etiketi", "Session label"), isPresented: $editingLabel) {
            TextField(model.t("Etiket", "Label"), text: $label)
            Button(model.t("Kaydet", "Save")) { model.mutateSession(session.id) { $0.label = String(label.prefix(80)) } }
            Button(model.t("Vazgeç", "Cancel"), role: .cancel) {}
        }
    }
}
