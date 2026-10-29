import XCTest
import CoreGraphics
@testable import DevIslandCore

final class PresentationTests: XCTestCase {
    func testV1PreferencesMigrateWithoutResettingUserChoices() throws {
        let v1 = Data(#"{"language":"tr","quiet":true,"volume":0.23,"soundMode":"file","customSoundPath":"/sounds/custom.aiff","preferredTerminal":"dev.warp.Warp-Stable","displayID":42,"shortcutKey":9,"retentionDays":14,"rules":{"question":{"island":false,"notification":true,"sound":false}}}"#.utf8)
        let p = try JSONDecoder().decode(Preferences.self, from: v1)
        XCTAssertEqual(p.language, "tr"); XCTAssertTrue(p.quiet); XCTAssertEqual(p.volume, 0.23)
        XCTAssertEqual(p.soundMode, "file"); XCTAssertEqual(p.preferredTerminal, "dev.warp.Warp-Stable")
        XCTAssertEqual(p.displayID, 42); XCTAssertEqual(p.shortcutKey, 9); XCTAssertEqual(p.retentionDays, 14)
        XCTAssertFalse(p.rule(for: .question).island); XCTAssertTrue(p.rule(for: .plan).sound)
        XCTAssertEqual(p.theme, .system); XCTAssertEqual(p.surface, .liquid); XCTAssertEqual(p.companionVisibility, .both)
    }
    func testAppearanceAndSeenStateRoundTrip() throws {
        var p = Preferences(); p.theme = .light; p.surface = .opaque; p.glassStyle = .clear
        p.mascotPlacement = .init(displayID: 7, x: 0.4, y: 0.6); p.mascotSize = 128
        p.seenCompletions = ["s": Date(timeIntervalSince1970: 1_800_000_000)]
        let r = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(r.theme, .light); XCTAssertEqual(r.surface, .opaque); XCTAssertEqual(r.glassStyle, .clear)
        XCTAssertEqual(r.mascotPlacement, p.mascotPlacement); XCTAssertEqual(r.mascotSize, 128)
        XCTAssertEqual(r.seenCompletions, p.seenCompletions)
    }
    func testMalformedNewValuesDoNotEraseLegacySettings() throws {
        let p = try JSONDecoder().decode(Preferences.self, from: Data(#"{"quiet":true,"theme":"future-theme","mascotSize":9999,"surfaceDensity":-10}"#.utf8))
        XCTAssertTrue(p.quiet); XCTAssertEqual(p.theme, .system); XCTAssertEqual(p.mascotSize, 160); XCTAssertEqual(p.surfaceDensity, 0)
    }
    func testTransitionReversalStartsFromActualIntermediateGeometry() {
        let small = IslandGeometry(width: 180, height: 36, radius: 18)
        let big = IslandGeometry(width: 460, height: 400, radius: 26, contentOpacity: 1)
        var t = IslandTransition(small)
        XCTAssertTrue(t.retarget(big, at: 10))
        XCTAssertEqual(t.duration, 0.32)
        let intermediate = t.sample(at: 10.12)
        XCTAssertGreaterThan(intermediate.height, small.height); XCTAssertLessThan(intermediate.height, big.height)
        t.retarget(small, at: 10.12)
        XCTAssertEqual(t.sample(at: 10.12), intermediate)
        XCTAssertEqual(t.duration, 0.24)
        XCTAssertEqual(t.sample(at: 11), small)
    }
    func testIdenticalTargetDoesNotRestartAnimation() {
        var t = IslandTransition(.init(width: 180, height: 36))
        let target = IslandGeometry(width: 460, height: 300, contentOpacity: 1)
        t.retarget(target, at: 1)
        let generation = t.generation
        XCTAssertFalse(t.retarget(target, at: 1.1)); XCTAssertEqual(t.started, 1); XCTAssertEqual(t.generation, generation)
    }
    func testMeasurementRoundingNoiseDoesNotRestartTransition() {
        var transition = IslandTransition(.init(width: 460, height: 300, radius: 26, contentOpacity: 1))
        XCTAssertFalse(transition.retarget(.init(width: 460, height: 301, radius: 26, contentOpacity: 1), at: 1))
        XCTAssertTrue(transition.retarget(.init(width: 460, height: 303, radius: 26, contentOpacity: 1), at: 2))
    }
    func testTransitionIsBoundedAndCompletesWithReducedMotion() {
        var t = IslandTransition(.init(width: 180, height: 36))
        let target = IslandGeometry(width: 460, height: 300, contentOpacity: 1)
        t.retarget(target, at: 1, reducedMotion: true)
        XCTAssertEqual(t.duration, 0.1)
        for i in 0...10 {
            let sample = t.sample(at: 1 + Double(i) / 100)
            XCTAssertTrue((180...460).contains(sample.width)); XCTAssertTrue((0...1).contains(sample.contentOpacity))
        }
        XCTAssertTrue(t.isFinished(at: 1.11)); XCTAssertEqual(t.sample(at: 1.11), target)
    }
    func testStaleHoverCallbacksAndPinnedCloseAreRejected() {
        var interaction = IslandInteraction()
        let first = interaction.enter()
        let exit = interaction.leave()
        XCTAssertFalse(interaction.permits(first, opening: true)); XCTAssertTrue(interaction.permits(exit, opening: false))
        _ = interaction.enter()
        XCTAssertFalse(interaction.permits(exit, opening: false))
        interaction.pin(); let leave = interaction.leave()
        XCTAssertFalse(interaction.permits(leave, opening: false))
        interaction.collapse(); let enter = interaction.enter()
        XCTAssertTrue(interaction.permits(enter, opening: true))
    }
    func session(_ id: String, _ state: SessionState, date: Double = 100) -> AgentSession {
        var s = AgentSession(id: id, cwd: "/Project", lastEvent: Date(timeIntervalSince1970: date), source: .init())
        s.state = state; return s
    }
    func testCompanionPriorityAndReadCompletions() {
        let list = [session("working", .running), session("done", .completed), session("error", .failed), session("ask", .question)]
        XCTAssertEqual(CompanionResolver.resolve(sessions: list, seen: [:]).sessionID, "ask")
        XCTAssertEqual(CompanionResolver.resolve(sessions: Array(list.prefix(3)), seen: [:]).sessionID, "error")
        XCTAssertEqual(CompanionResolver.resolve(sessions: Array(list.prefix(2)), seen: [:]).sessionID, "done")
        XCTAssertEqual(CompanionResolver.resolve(sessions: Array(list.prefix(2)), seen: ["done": Date(timeIntervalSince1970: 100)]).sessionID, "working")
    }
    func testCelebrationOnlyForNewLiveUnmutedCompletion() {
        var gate = CelebrationGate(), s = session("s", .completed), p = Preferences()
        let id = UUID()
        XCTAssertFalse(gate.allow(eventID: id, session: s, preferences: p, replay: true))
        XCTAssertTrue(gate.allow(eventID: id, session: s, preferences: p, replay: false))
        XCTAssertFalse(gate.allow(eventID: id, session: s, preferences: p, replay: false))
        s.muted = true
        XCTAssertFalse(gate.allow(eventID: UUID(), session: s, preferences: p, replay: false))
        s.muted = false; p.quiet = true
        XCTAssertFalse(gate.allow(eventID: UUID(), session: s, preferences: p, replay: false))
        p.quiet = false; s.revalidated = false
        XCTAssertFalse(gate.allow(eventID: UUID(), session: s, preferences: p, replay: false))
    }
    func testCompletionPoseDoesNotCelebrateOnRestoration() {
        let s = session("s", .completed)
        XCTAssertEqual(CompanionResolver.resolve(sessions: [s], seen: [:]).pose, .idle)
        XCTAssertEqual(CompanionResolver.resolve(sessions: [s], seen: [:], celebrating: "s").pose, .celebration)
    }
    func testMascotPositionRoundTripAcrossNegativeScreenOrigin() {
        let frame = CGRect(x: -1920, y: 0, width: 1920, height: 1080), size = CGSize(width: 96, height: 96)
        let placement = MascotPlacement(displayID: 8, x: 0.25, y: 0.7)
        let origin = MascotLayout.origin(placement: placement, frame: frame, size: size)
        let restored = MascotLayout.placement(origin: origin, frame: frame, size: size, displayID: 8)
        XCTAssertEqual(restored.x, placement.x, accuracy: 0.00001); XCTAssertEqual(restored.y, placement.y, accuracy: 0.00001)
    }
    func testMascotClampsAfterScreenRemovalOrCorruptPosition() {
        let frame = CGRect(x: 0, y: 0, width: 1440, height: 850)
        let origin = MascotLayout.origin(placement: .init(displayID: 999, x: 100, y: -100), frame: frame, size: CGSize(width: 96, height: 96))
        XCTAssertEqual(origin.x, 1440 - 96 - 16); XCTAssertEqual(origin.y, 16)
    }
    func testTransparentMascotCornersDoNotInterceptClicks() {
        let size = CGSize(width: 96, height: 96)
        XCTAssertFalse(ClawdHitMask.contains(point: CGPoint(x: 1, y: 1), size: size, pose: .idle))
        XCTAssertFalse(ClawdHitMask.contains(point: CGPoint(x: 95, y: 95), size: size, pose: .working))
        XCTAssertTrue(ClawdHitMask.contains(point: CGPoint(x: 48, y: 48), size: size, pose: .idle))
        XCTAssertTrue(ClawdHitMask.contains(point: CGPoint(x: 80, y: 10), size: size, pose: .question))
    }
}
