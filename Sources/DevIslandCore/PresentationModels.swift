import Foundation
import CoreGraphics

public enum ClawdPose: String, CaseIterable { case idle, working, question, plan, permission, celebration, failed, disconnected }

public struct CompanionActivity: Equatable {
    public var sessionID: String?
    public var pose: ClawdPose
    public var state: SessionState
    public var waitingCount: Int
    public init(sessionID: String? = nil, pose: ClawdPose = .idle, state: SessionState = .idle, waitingCount: Int = 0) {
        self.sessionID = sessionID; self.pose = pose; self.state = state; self.waitingCount = waitingCount
    }
}

public enum CompanionResolver {
    public static func resolve(sessions: [AgentSession], seen: [String: Date], celebrating: String? = nil) -> CompanionActivity {
        let active = sessions.filter(\.isActive)
        let sorted = active.sorted {
            func rank(_ s: AgentSession) -> Int {
                if s.state == .completed && (seen[s.id] ?? .distantPast) >= s.lastEvent { return 9 }
                return s.state.priority
            }
            return rank($0) == rank($1) ? $0.lastEvent > $1.lastEvent : rank($0) < rank($1)
        }
        guard let session = sorted.first else { return .init() }
        let pose: ClawdPose
        switch session.state {
        case .question: pose = .question
        case .plan: pose = .plan
        case .permission: pose = .permission
        case .running: pose = .working
        case .failed: pose = .failed
        case .disconnected: pose = .disconnected
        case .completed: pose = celebrating == session.id ? .celebration : .idle
        default: pose = .idle
        }
        return CompanionActivity(sessionID: session.id, pose: pose, state: session.state,
                                 waitingCount: active.filter { $0.state.needsAttention }.count)
    }
}

public struct CelebrationGate {
    private var consumed = Set<UUID>()
    public init() {}
    public mutating func allow(eventID: UUID, session: AgentSession, preferences: Preferences,
                               replay: Bool, awake: Bool = true, now: Date = Date()) -> Bool {
        guard !replay, awake, session.state == .completed, session.revalidated, !session.muted,
              !preferences.isQuiet(at: now), !(session.snoozedUntil.map { $0 > now } ?? false),
              !consumed.contains(eventID) else { return false }
        consumed.insert(eventID)
        return true
    }
}

public enum IslandMode: String, Equatable { case compact, alert, expanded }
public struct IslandGeometry: Equatable {
    public var width: Double
    public var height: Double
    public var radius: Double
    public var contentOpacity: Double
    public init(width: Double, height: Double, radius: Double = 24, contentOpacity: Double = 0) {
        self.width = width; self.height = height; self.radius = radius; self.contentOpacity = contentOpacity
    }
    public func blended(to target: Self, progress: Double) -> Self {
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * progress }
        return Self(width: mix(width, target.width), height: mix(height, target.height),
                    radius: mix(radius, target.radius), contentOpacity: min(1, max(0, mix(contentOpacity, target.contentOpacity))))
    }
}

/// A clock-driven, interruptible transition; the AppKit window and SwiftUI content share every sample.
public struct IslandTransition {
    public private(set) var target: IslandGeometry
    public private(set) var from: IslandGeometry
    public private(set) var started: TimeInterval = 0
    public private(set) var duration: TimeInterval = 0
    public private(set) var generation: UInt64 = 0
    public init(_ geometry: IslandGeometry) { target = geometry; from = geometry }
    public func sample(at time: TimeInterval) -> IslandGeometry {
        guard duration > 0 else { return target }
        let t = min(1, max(0, (time - started) / duration))
        if t >= 1 { return target }
        // Monotone, critically damped spring normalized to finish exactly at t=1.
        let spring = (1 - (1 + 7 * t) * exp(-7 * t)) / (1 - 8 * exp(-7))
        return from.blended(to: target, progress: spring)
    }
    public func isFinished(at time: TimeInterval) -> Bool { time >= started + duration }
    @discardableResult public mutating func retarget(_ next: IslandGeometry, at time: TimeInterval, reducedMotion: Bool = false) -> Bool {
        guard abs(next.width - target.width) > 0.5 || abs(next.height - target.height) > 1 ||
              abs(next.radius - target.radius) > 0.25 || abs(next.contentOpacity - target.contentOpacity) > 0.001 else { return false }
        from = sample(at: time); target = next; started = time
        duration = reducedMotion ? 0.1 : (next.height < from.height ? 0.24 : 0.32)
        generation &+= 1
        return true
    }
}

public struct IslandInteraction {
    public private(set) var generation: UInt64 = 0
    public private(set) var pinned = false
    public private(set) var hovered = false
    public init() {}
    public mutating func enter() -> UInt64 { hovered = true; generation &+= 1; return generation }
    public mutating func leave() -> UInt64 { hovered = false; generation &+= 1; return generation }
    public mutating func pin() { pinned = true; generation &+= 1 }
    public mutating func collapse() { pinned = false; generation &+= 1 }
    public func permits(_ ticket: UInt64, opening: Bool) -> Bool {
        ticket == generation && !pinned && (opening ? hovered : !hovered)
    }
}

public enum MascotLayout {
    /// Visible-frame coordinates, including negative origins on secondary screens.
    public static func origin(placement: MascotPlacement, frame: CGRect, size: CGSize, margin: Double = 16) -> CGPoint {
        let minX = frame.minX + margin, minY = frame.minY + margin
        let roomX = max(0, frame.width - size.width - margin * 2), roomY = max(0, frame.height - size.height - margin * 2)
        return CGPoint(x: minX + min(1, max(0, placement.x)) * roomX, y: minY + min(1, max(0, placement.y)) * roomY)
    }
    public static func placement(origin: CGPoint, frame: CGRect, size: CGSize, displayID: UInt32, margin: Double = 16) -> MascotPlacement {
        let roomX = max(1, frame.width - size.width - margin * 2), roomY = max(1, frame.height - size.height - margin * 2)
        return MascotPlacement(displayID: displayID, x: min(1, max(0, (origin.x - frame.minX - margin) / roomX)),
                               y: min(1, max(0, (origin.y - frame.minY - margin) / roomY)))
    }
}

public enum ClawdHitMask {
    public static func contains(point: CGPoint, size: CGSize, pose: ClawdPose) -> Bool {
        MascotSilhouette.contains(point: point, size: size, kind: .clawd, pose: pose)
    }
}
