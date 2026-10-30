import Foundation
import CoreGraphics

public struct IslandPlacement: Codable, Equatable {
    public var displayID: UInt32
    public var isCustom: Bool
    /// Header center / header top, normalized in the screen's visible frame (AppKit coordinates).
    public var x: Double
    public var y: Double
    public init(displayID: UInt32 = 0, isCustom: Bool = false, x: Double = 0.5, y: Double = 1) {
        self.displayID = displayID; self.isCustom = isCustom; self.x = x; self.y = y
    }
}
public struct IslandAnchor: Equatable {
    public var centerX: Double
    public var headerTop: Double
    public var attachedToTop: Bool
    public init(centerX: Double, headerTop: Double, attachedToTop: Bool = false) {
        self.centerX = centerX; self.headerTop = headerTop; self.attachedToTop = attachedToTop
    }
}
public enum IslandLayout {
    private static func unit(_ n: Double) -> Double { n.isFinite ? min(1, max(0, n)) : 0.5 }
    public static func anchor(placement: IslandPlacement, screen: CGRect, visible: CGRect, header: CGSize) -> IslandAnchor {
        if !placement.isCustom { return .init(centerX: screen.midX, headerTop: screen.maxY, attachedToTop: true) }
        let half = min(header.width, visible.width) / 2
        let minX = visible.minX + half, maxX = max(minX, visible.maxX - half)
        let minTop = visible.minY + min(header.height, visible.height)
        return .init(centerX: min(maxX, max(minX, visible.minX + unit(placement.x) * visible.width)),
                     headerTop: min(visible.maxY, max(minTop, visible.minY + unit(placement.y) * visible.height)))
    }
    public static func placement(anchor: IslandAnchor, screen: CGRect, visible: CGRect, displayID: UInt32, snap: Bool = true) -> IslandPlacement {
        if snap && abs(anchor.centerX - screen.midX) <= 32 && anchor.headerTop >= visible.maxY - 18 {
            return .init(displayID: displayID)
        }
        return .init(displayID: displayID, isCustom: true,
                     x: unit((anchor.centerX - visible.minX) / max(1, visible.width)),
                     y: unit((anchor.headerTop - visible.minY) / max(1, visible.height)))
    }
    public static func opensUpward(anchor: IslandAnchor, visible: CGRect, headerHeight: Double) -> Bool {
        !anchor.attachedToTop && visible.maxY - anchor.headerTop > anchor.headerTop - headerHeight - visible.minY
    }
    public static func bodyRoom(anchor: IslandAnchor, visible: CGRect, headerHeight: Double, upward: Bool) -> Double {
        max(0, (upward ? visible.maxY - anchor.headerTop : anchor.headerTop - headerHeight - visible.minY) - 8)
    }
    public static func frame(anchor: IslandAnchor, size: CGSize, headerHeight: Double, visible: CGRect, upward: Bool) -> CGRect {
        let x = min(max(visible.minX, visible.maxX - size.width), max(visible.minX, anchor.centerX - size.width / 2))
        // The header is the anchor. Growing upward keeps its bottom edge fixed.
        return CGRect(x: x, y: upward ? anchor.headerTop - headerHeight : anchor.headerTop - size.height, width: size.width, height: size.height)
    }
}

/// Mouse recognition independent of event frequency and SwiftUI view updates.
public struct IslandDragGesture {
    private var start: CGPoint?
    public private(set) var isDragging = false
    public private(set) var translation = CGPoint.zero
    public init() {}
    public mutating func press(at point: CGPoint) { start = point; isDragging = false; translation = .zero }
    @discardableResult public mutating func move(to point: CGPoint) -> Bool {
        guard let start else { return false }
        translation = CGPoint(x: point.x - start.x, y: point.y - start.y)
        if hypot(translation.x, translation.y) >= 4 { isDragging = true }
        return isDragging
    }
    public mutating func release() -> Bool {
        let dragged = isDragging; start = nil; isDragging = false; return dragged
    }
    public mutating func cancel() { start = nil; isDragging = false; translation = .zero }
}
