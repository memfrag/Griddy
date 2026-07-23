//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// A grabbable point on a primitive, and what dragging it does.
///
/// Handles are *semantic*: a circle's is its radius, a line's are its ends, a
/// rounded rectangle's are its corners and its corner radius. Modelling the
/// role rather than just the point is what lets one drag mean "resize" on one
/// primitive and "move this vertex" on another. See spec 8.3.
public enum PrimitiveHandle: Hashable, Sendable {

    /// A centre-anchored primitive's centre, dragged to move it. Duplicates a
    /// body drag but gives a precise grab point, and its dot marks the centre.
    case center

    /// The extent of a circle, dragged to change its radius.
    case radius

    case lineStart
    case lineEnd

    /// An arc's radius, start angle and end angle.
    case arcRadius
    case arcStart
    case arcEnd

    /// A corner of a rectangular primitive, dragged to resize.
    case corner(RectCorner)

    /// A rounded rectangle's corner radius.
    case cornerRadius

    /// A vertex of a polyline or symmetric path.
    case vertex(Int)
}

public enum RectCorner: Hashable, Sendable, CaseIterable {
    case topLeft, topRight, bottomRight, bottomLeft

    /// The corner diagonally across, which stays put while this one is dragged.
    var opposite: RectCorner {
        switch self {
        case .topLeft: .bottomRight
        case .topRight: .bottomLeft
        case .bottomRight: .topLeft
        case .bottomLeft: .topRight
        }
    }

    func point(of rect: IconRect) -> IconPoint {
        switch self {
        case .topLeft: IconPoint(x: rect.minX, y: rect.maxY)
        case .topRight: IconPoint(x: rect.maxX, y: rect.maxY)
        case .bottomRight: IconPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft: IconPoint(x: rect.minX, y: rect.minY)
        }
    }
}

/// A handle at a concrete position, for drawing and hit testing.
public struct HandlePoint: Hashable, Sendable {
    public let handle: PrimitiveHandle
    public let position: IconPoint

    public init(_ handle: PrimitiveHandle, at position: IconPoint) {
        self.handle = handle
        self.position = position
    }
}

public extension IconPrimitive {

    /// The primitive's grabbable handles, in draw order.
    ///
    /// Empty for compounds and imported paths: neither has a parametric form to
    /// reshape through a handle. They can still be moved as a whole.
    var handles: [HandlePoint] {
        switch self {
        case .circle(let circle):
            return [HandlePoint(.center, at: circle.center),
                    HandlePoint(.radius,
                                at: IconPoint(x: circle.center.x + circle.radius,
                                              y: circle.center.y))]

        case .line(let line):
            return [HandlePoint(.lineStart, at: line.start),
                    HandlePoint(.lineEnd, at: line.end)]

        case .arc(let arc):
            let mid = IconAngle(radians: arc.startAngle.radians
                + (arc.isClockwise ? -arc.sweep : arc.sweep) / 2)
            return [HandlePoint(.center, at: arc.center),
                    HandlePoint(.arcStart, at: arc.startPoint),
                    HandlePoint(.arcEnd, at: arc.endPoint),
                    HandlePoint(.arcRadius, at: arc.point(atAngle: mid))]

        case .roundedRect(let rect):
            return cornerHandles(of: rect.bounds) + [
                HandlePoint(.cornerRadius,
                            at: IconPoint(x: rect.bounds.minX
                                          + rect.effectiveCornerRadius,
                                          y: rect.bounds.maxY))]

        case .capsule(let capsule):
            return cornerHandles(of: capsule.bounds)

        case .polyline(let polyline):
            return polyline.points.enumerated().map {
                HandlePoint(.vertex($0.offset), at: $0.element)
            }

        case .symmetricPath(let path):
            return path.points.enumerated().map {
                HandlePoint(.vertex($0.offset), at: $0.element)
            }

        case .compound, .importedPath:
            return []
        }
    }

    private func cornerHandles(of rect: IconRect) -> [HandlePoint] {
        RectCorner.allCases.map { HandlePoint(.corner($0), at: $0.point(of: rect)) }
    }

    /// The primitive with one handle dragged to a new point.
    ///
    /// Each handle is single-purpose, so this never has to guess intent from
    /// the gesture. Sizes clamp at zero; a rectangle stays a rectangle by
    /// spanning the dragged corner and its fixed opposite.
    func moving(_ handle: PrimitiveHandle, to point: IconPoint) -> IconPrimitive {
        switch (self, handle) {
        case (_, .center):
            return movingAnchor(to: point)

        case (.circle(var circle), .radius):
            circle.radius = max(0, circle.center.distance(to: point))
            return .circle(circle)

        case (.line(var line), .lineStart):
            line.start = point
            return .line(line)
        case (.line(var line), .lineEnd):
            line.end = point
            return .line(line)

        case (.arc(var arc), .arcStart):
            arc.startAngle = angle(from: arc.center, to: point)
            return .arc(arc)
        case (.arc(var arc), .arcEnd):
            arc.endAngle = angle(from: arc.center, to: point)
            return .arc(arc)
        case (.arc(var arc), .arcRadius):
            arc.radius = max(0, arc.center.distance(to: point))
            return .arc(arc)

        case (.roundedRect(var rect), .corner(let corner)):
            rect.bounds = resized(rect.bounds, movingCorner: corner, to: point)
            return .roundedRect(rect)
        case (.roundedRect(var rect), .cornerRadius):
            rect.cornerRadius = max(0, point.x - rect.bounds.minX)
            return .roundedRect(rect)

        case (.capsule(var capsule), .corner(let corner)):
            capsule.bounds = resized(capsule.bounds, movingCorner: corner, to: point)
            return .capsule(capsule)

        case (.polyline(var polyline), .vertex(let index)):
            guard polyline.points.indices.contains(index) else { return self }
            polyline.points[index] = point
            return .polyline(polyline)

        case (.symmetricPath(var path), .vertex(let index)):
            guard path.points.indices.contains(index) else { return self }
            path.points[index] = point
            return .symmetricPath(path)

        default:
            return self
        }
    }

    /// The angle from a centre to a point, as the arc measures angles.
    private func angle(from centre: IconPoint, to point: IconPoint) -> IconAngle {
        IconAngle(radians: atan2(point.y - centre.y, point.x - centre.x))
    }

    /// A rectangle re-spanned so one corner follows the pointer while its
    /// diagonal opposite stays put.
    private func resized(_ rect: IconRect,
                         movingCorner corner: RectCorner,
                         to point: IconPoint) -> IconRect {
        let fixed = corner.opposite.point(of: rect)
        return IconRect(x: Swift.min(fixed.x, point.x),
                        y: Swift.min(fixed.y, point.y),
                        width: abs(point.x - fixed.x),
                        height: abs(point.y - fixed.y))
    }
}
