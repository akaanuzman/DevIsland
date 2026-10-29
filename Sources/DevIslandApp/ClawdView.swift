import SwiftUI
import DevIslandCore

/// Native pixel geometry, with no runtime downloads, web view, or third-party animation engine.
struct ClawdView: View {
    let pose: ClawdPose
    var kind: MascotKind = .clawd
    var bodyHex = "D97757"
    var size: CGFloat = 96
    var active = true
    var celebrationStarted: Date?
    var sampleTime: Double?
    // Offscreen previews/tests can supply this read-only macOS accessibility input deterministically.
    var motionOverride: Bool?
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { motionOverride ?? systemReduceMotion }
    @Environment(\.snapshotPreview) private var snapshot
    @State private var transientSettled = false
    @State private var poseStarted = Date()
    var body: some View {
        TimelineView(.animation(minimumInterval: pose == .idle ? 0.25 : 1.0 / 15.0, paused: !active || reduceMotion || snapshot || pose == .disconnected || ([ClawdPose.failed, .plan].contains(pose) && transientSettled))) { timeline in
            Canvas { context, frame in
                let elapsed = reduceMotion ? 0 : (sampleTime ?? (snapshot ? 0 : timeline.date.timeIntervalSinceReferenceDate))
                draw(context: &context, frame: frame, time: elapsed, age: sampleTime ?? Date().timeIntervalSince(poseStarted))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(kind.rawValue.capitalized)
        .accessibilityValue(pose.rawValue)
        .allowsHitTesting(false)
        .task(id: pose) {
            poseStarted = Date(); transientSettled = false
            if pose == .failed || pose == .plan {
                try? await Task.sleep(nanoseconds: 800_000_000)
                if !Task.isCancelled { transientSettled = true }
            }
        }
    }
    private func draw(context: inout GraphicsContext, frame: CGSize, time: Double, age: Double) {
        let scale = min(frame.width, frame.height) / 32
        context.scaleBy(x: scale, y: scale)
        if pose == .failed && age < 0.65 && !reduceMotion { context.translateBy(x: (sin(age * 30) * (1 - age / 0.65)).rounded(), y: 0) }
        let phase = time * 4
        let celebrateTime = sampleTime ?? celebrationStarted.map { max(0, Date().timeIntervalSince($0)) } ?? 0.4
        let jump = pose == .celebration && !reduceMotion ? -abs(sin(min(1, celebrateTime / 1.2) * .pi * 2)) * 3 : 0
        let bob = pose == .working ? sin(phase) * 0.6 : (pose == .idle ? sin(time * 1.6) * 0.55 : 0)
        let y = (jump + bob).rounded(.toNearestOrAwayFromZero)
        let rgb = SRGBColor(hex: pose == .disconnected ? "ACAEA9" : bodyHex)
        let orange = Color(rgb), shadow = Color(rgb.mixed(with: .black, amount: 0.3))
        let eye = Color(rgb.ink), highlight = Color(rgb.mixed(with: .white, amount: 0.45))
        func pixel(_ rect: CGRect, _ color: Color) { context.fill(Path(rect), with: .color(color)) }
        func box(_ x: Double, _ top: Double, _ w: Double, _ h: Double, _ color: Color) {
            pixel(CGRect(x: x, y: top + y, width: w, height: h), color)
        }
        for rect in MascotSilhouette.body(kind) {
            pixel(rect.offsetBy(dx: 0, dy: y), orange)
        }
        // A perimeter, rather than an overall tint filter, preserves very light/dark custom colors.
        let perimeter = Path(MascotSilhouette.outline(kind)).offsetBy(dx: 0, dy: y)
        context.stroke(perimeter, with: .color(eye.opacity(0.45)), lineWidth: 0.4)
        let blink = pose == .idle && time.truncatingRemainder(dividingBy: 5) > 4.75
        let eyeTop = pose == .question || pose == .plan || pose == .permission ? 12.0 : 14.0
        switch kind {
        case .clawd:
            box(7, 20, 18, 2, shadow)
            box(10, eyeTop, 2, blink ? 1 : 3, eye); box(20, eyeTop, 2, blink ? 1 : 3, eye)
        case .cat:
            box(9, 7, 2, 3, highlight); box(21, 7, 2, 3, highlight)
            box(11, eyeTop, 2, blink ? 1 : 2, eye); box(19, eyeTop, 2, blink ? 1 : 2, eye)
            box(15, 17, 2, 1, eye); box(14, 18, 1, 1, eye); box(17, 18, 1, 1, eye)
            box(8, 18, 4, 1, shadow); box(20, 18, 4, 1, shadow)
            box(11, 23, 3, 3, highlight); box(18, 23, 3, 3, highlight)
        case .robot:
            box(10, 10, 12, 8, eye)
            box(12, eyeTop - 1, 2, blink ? 1 : 2, orange); box(18, eyeTop - 1, 2, blink ? 1 : 2, orange)
            box(13, 23, 6, 1, eye); box(6, 16, 1, 4, highlight); box(25, 16, 1, 4, highlight)
            box(14, 3, 4, 2, highlight)
        }
        if pose == .working {
            box(8, 21, 16, 8, Color(hex: "3B515C")); box(10, 22, 12, 5, Color(hex: "AADAE0"))
            box(6, 29, 20, 1, Color(hex: "474747"))
            let tap = sin(phase * 2) > 0 ? 0.0 : 1.0
            box(6, 23 + tap, 3, 2, orange); box(23, 24 - tap, 3, 2, orange)
            box(12, 24, 3, 1, Color(hex: "34858E")); box(16, 24, 4, 1, Color(hex: "34858E"))
        }
        if pose == .question {
            bubble(context: &context, symbol: "?", fill: Color(hex: "F4E7CB"), time: time)
        } else if pose == .permission {
            box(27, 8, 3, 7, orange)
            bubble(context: &context, symbol: "lock.fill", fill: Color(hex: "F4E7CB"), time: time)
        } else if pose == .plan {
            let lift = reduceMotion ? 0.0 : (max(0, 1 - age / 0.45) * 3).rounded()
            box(20, 18 + lift, 9, 11, Color(hex: "EFE8D5")); box(22, 21 + lift, 5, 1, shadow)
            box(22, 24 + lift, 5, 1, shadow); box(22, 27 + lift, 3, 1, shadow)
        } else if pose == .celebration {
            box(3, 8, 3, 6, orange); box(26, 7, 3, 7, orange)
            box(13, 18, 6, 1, eye)
            for i in 0..<5 {
                let x = Double(i * 6 + 2), dy = sin(phase + Double(i)) * 2
                pixel(CGRect(x: x, y: 4 + dy, width: 1, height: 2), i % 2 == 0 ? orange : highlight)
            }
        } else if pose == .failed {
            bubble(context: &context, symbol: "!", fill: Color(hex: "F6D6CE"), time: age < 0.8 ? time : 0)
            box(12, 19, 7, 1, eye)
        }
    }
    private func bubble(context: inout GraphicsContext, symbol: String, fill: Color, time: Double) {
        let y = 1 + (reduceMotion ? 0.0 : (sin(time * 2) * 0.8).rounded())
        context.fill(Path(roundedRect: CGRect(x: 20, y: y, width: 11, height: 10), cornerRadius: 3), with: .color(fill))
        context.fill(Path(CGRect(x: 21, y: 8 + y, width: 2, height: 4)), with: .color(fill))
        if symbol == "lock.fill" {
            context.fill(Path(CGRect(x: 23, y: 5 + y, width: 5, height: 4)), with: .color(Color(hex: "644633")))
            context.stroke(Path(roundedRect: CGRect(x: 24, y: 2 + y, width: 3, height: 5), cornerRadius: 1.5), with: .color(Color(hex: "644633")), lineWidth: 1)
        } else {
            context.draw(Text(symbol).font(.system(size: 8, weight: .heavy, design: .monospaced)).foregroundColor(Color(hex: "644633")), at: CGPoint(x: 25.5, y: 5 + y))
        }
    }
}

struct ClawdContactSheet: View {
    var kind: MascotKind = .clawd
    var hex = "D97757"
    let poses: [ClawdPose] = [.idle, .working, .question, .plan, .permission, .celebration, .failed, .disconnected]
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<2) { row in
                HStack(spacing: 0) {
                    ForEach(0..<4) { column in
                        let pose = poses[row * 4 + column]
                        VStack(spacing: 8) {
                            ClawdView(pose: pose, kind: kind, bodyHex: hex, size: 100, active: false, sampleTime: 0.35)
                            Text(pose.rawValue).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(Color(hex: "474747"))
                        }.frame(width: 160, height: 160)
                    }
                }
            }
        }
    }
}

struct CompanionView: View {
    @ObservedObject var model: AppModel
    var size: CGFloat = 96
    var active = true
    var body: some View {
        ClawdView(pose: model.companion.pose, kind: model.preferences.mascot,
                  bodyHex: model.preferences.mascotHex, size: size, active: active && model.visualsAwake,
                  celebrationStarted: model.celebrationStarted)
    }
}
extension AppModel {
    var mascotName: String {
        switch preferences.mascot {
        case .clawd: return "Clawd"
        case .cat: return t("Kedi", "Cat")
        case .robot: return "Robot"
        }
    }
}

struct MascotColorSheet: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(MascotKind.allCases, id: \.self) { kind in
                HStack(spacing: 0) {
                    ForEach(["D97757", "7EB4DA", "9B87C8", "FFFFFF", "000000"], id: \.self) { color in
                        VStack(spacing: 4) {
                            ClawdView(pose: .idle, kind: kind, bodyHex: color, size: 80, active: false, sampleTime: 0)
                            Text("#" + color).font(.system(size: 10, design: .monospaced)).foregroundStyle(Color(hex: "474747"))
                        }.frame(width: 112, height: 120)
                    }
                }
            }
        }
    }
}
