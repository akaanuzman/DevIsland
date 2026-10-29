import XCTest
import SwiftUI
import AppKit
import DevIslandCore
@testable import DevIslandApp

final class LayoutTests: XCTestCase {
    @MainActor func model(sessions: Int) -> AppModel {
        let m = AppModel(paths: AppPaths(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)),
                         defaults: UserDefaults(suiteName: "dev.island.layout-tests." + UUID().uuidString)!, loadPersistentState: false)
        m.preferences = Preferences(); m.preferences.language = "en"
        for i in 0..<sessions {
            m.ledger.apply(AgentEvent(sessionID: "layout-\(i)", kind: .question, cwd: "/Projects/Project-\(i)-with-a-very-long-name-that-must-truncate", toolCallID: "call-\(i)"))
        }
        return m
    }
    @MainActor func testCompactHostHasNoImplicitMinimumAndBodyDoesNotInflateItsFittingHeight() {
        let m = model(sessions: 10), p = IslandPresentation()
        for header in [36.0, 38.0] {
            p.safeTop = header; p.geometry = .init(width: 330, height: header, radius: 18)
            let host = PanelSizing.host(IslandView(model: m, presentation: p))
            XCTAssertEqual(host.sizingOptions, [])
            host.frame = CGRect(x: 0, y: 0, width: 330, height: header)
            host.layoutSubtreeIfNeeded()
            XCTAssertEqual(host.frame.height, header, accuracy: 0.01)
            // Both the settled compact state and a still-mounted body during closing must fit.
            for body in [IslandMode.compact, .expanded, .alert] {
                p.bodyMode = body
                let size = PanelSizing.height(of: IslandView(model: m, presentation: p), width: 330, maximum: 10_000)
                XCTAssertEqual(size, header, accuracy: 1)
            }
        }
    }
    @MainActor func testRealCompactPanelFrameRemainsAtHeaderHeightAfterHostingLayout() {
        let m = model(sessions: 10), p = IslandPresentation()
        p.safeTop = 36; p.geometry = .init(width: 330, height: 36)
        p.bodyMode = .expanded // Closing animation still has a mounted list.
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.contentView = PanelSizing.host(IslandView(model: m, presentation: p))
        panel.setFrame(CGRect(x: 100, y: 100, width: 330, height: 36), display: true)
        panel.contentView?.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        XCTAssertEqual(panel.frame.height, 36, accuracy: 0.01)
        XCTAssertEqual(panel.contentView?.frame.height ?? 0, 36, accuracy: 0.01)
        XCTAssertEqual(panel.minSize.height, 0, accuracy: 0.01)
        panel.close()
    }
    @MainActor func testMeasuredPanelsGrowWithActualRowsThenCapAtViewport() {
        var heights: [CGFloat] = []
        for count in [0, 1, 3, 10] {
            let m = model(sessions: count)
            let natural = PanelSizing.height(of: SessionTrayView(model: m, close: {}).appTheme(m.preferences), width: 460, maximum: 10_000)
            let limited = PanelSizing.height(of: SessionTrayView(model: m, close: {}).appTheme(m.preferences), width: 460, maximum: 520)
            XCTAssertGreaterThan(natural, 60); XCTAssertLessThan(natural, 1500)
            XCTAssertEqual(limited, min(520, natural))
            heights.append(limited)
            print("Measured panel: sessions=\(count) natural=\(natural) viewport=\(limited)")
            let tray = PanelSizing.height(of: MascotTrayView(model: m, close: {}), width: 400, maximum: 580)
            XCTAssertLessThanOrEqual(tray, 580); XCTAssertGreaterThan(tray, limited)
        }
        XCTAssertLessThan(heights[1], heights[2]); XCTAssertLessThan(heights[2], heights[3]); XCTAssertEqual(heights[3], 520)
    }
    @MainActor func testThemeCoordinatorUpdatesNativeWindowsAndAttachedPanelsTogether() {
        let app = NSApplication.shared
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 300, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
        let child = NSPanel(contentRect: CGRect(x: 0, y: 0, width: 100, height: 80), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; child.isReleasedWhenClosed = false
        window.addChildWindow(child, ordered: .above)
        defer { window.removeChildWindow(child); child.close(); window.close(); app.appearance = nil }
        for mode in [ThemeMode.dark, .light, .system, .dark] {
            var prefs = Preferences(); prefs.theme = mode
            ThemeCoordinator.shared.update(prefs)
            if mode == .system {
                XCTAssertNil(app.appearance); XCTAssertNil(window.appearance); XCTAssertNil(child.appearance)
            } else {
                let expected: NSAppearance.Name = mode == .dark ? .darkAqua : .aqua
                XCTAssertEqual(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]), expected)
                XCTAssertEqual(child.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]), expected)
                var luminance = 0.0
                child.effectiveAppearance.performAsCurrentDrawingAppearance {
                    let color = NSColor.labelColor.usingColorSpace(.sRGB)!
                    luminance = SRGBColor(r: color.redComponent, g: color.greenComponent, b: color.blueComponent).luminance
                }
                if mode == .dark { XCTAssertGreaterThan(luminance, 0.8) }
                else { XCTAssertLessThan(luminance, 0.1) }
            }
        }
    }
    @MainActor func testReduceMotionFreezesAllThreeRenderedCharactersInEveryPose() throws {
        func pixels(kind: MascotKind, pose: ClawdPose, time: Double) throws -> Data {
            let view = ClawdView(pose: pose, kind: kind, bodyHex: "7EB4DA", size: 96, active: false, sampleTime: time, motionOverride: true)
                .environment(\.snapshotPreview, true)
            let renderer = ImageRenderer(content: view)
            return try XCTUnwrap(renderer.cgImage?.dataProvider?.data) as Data
        }
        for kind in MascotKind.allCases {
            for pose in ClawdPose.allCases {
                let first = try pixels(kind: kind, pose: pose, time: 0)
                let later = try pixels(kind: kind, pose: pose, time: 1.1)
                XCTAssertTrue(first == later, "Reduce Motion changed pixels: \(kind.rawValue)/\(pose.rawValue)")
            }
        }
    }
    @MainActor func testChangingMetadataWithoutGeometryDoesNotRestartTransition() {
        let m = model(sessions: 3)
        let before = PanelSizing.height(of: SessionTrayView(model: m, close: {}), width: 460, maximum: 520)
        m.ledger.sessions["layout-0"]?.label = "A short label"
        let after = PanelSizing.height(of: SessionTrayView(model: m, close: {}), width: 460, maximum: 520)
        XCTAssertEqual(before, after)
        var transition = IslandTransition(.init(width: 180, height: 36))
        transition.retarget(.init(width: 460, height: before + 36, contentOpacity: 1), at: 1)
        XCTAssertFalse(transition.retarget(.init(width: 460, height: after + 36, contentOpacity: 1), at: 1.1))
    }
}
