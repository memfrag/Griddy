//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// A straight segment between two points.
public struct LinePrimitive: Codable, Hashable, Sendable, Identifiable {

    public var id: PrimitiveID
    public var attributes: PrimitiveAttributes
    public var start: IconPoint
    public var end: IconPoint

    public init(id: PrimitiveID = PrimitiveID(),
                attributes: PrimitiveAttributes = .default,
                start: IconPoint,
                end: IconPoint) {
        self.id = id
        self.attributes = attributes
        self.start = start
        self.end = end
    }

    public var length: Double {
        start.distance(to: end)
    }
}

/// A circular arc, swept from `startAngle` to `endAngle`.
public struct ArcPrimitive: Codable, Hashable, Sendable, Identifiable {

    public var id: PrimitiveID
    public var attributes: PrimitiveAttributes
    public var center: IconPoint
    public var radius: Double
    public var startAngle: IconAngle
    public var endAngle: IconAngle

    /// Sweep direction. Counterclockwise matches the positive angular
    /// direction of Griddy's Y-up coordinate space.
    public var isClockwise: Bool

    public init(id: PrimitiveID = PrimitiveID(),
                attributes: PrimitiveAttributes = .default,
                center: IconPoint,
                radius: Double,
                startAngle: IconAngle,
                endAngle: IconAngle,
                isClockwise: Bool = false) {
        self.id = id
        self.attributes = attributes
        self.center = center
        self.radius = radius
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.isClockwise = isClockwise
    }

    public func point(atAngle angle: IconAngle) -> IconPoint {
        center.offset(by: angle.direction.scaled(by: radius))
    }

    public var startPoint: IconPoint {
        point(atAngle: startAngle)
    }

    public var endPoint: IconPoint {
        point(atAngle: endAngle)
    }
}

/// A full circle.
public struct CirclePrimitive: Codable, Hashable, Sendable, Identifiable {

    public var id: PrimitiveID
    public var attributes: PrimitiveAttributes
    public var center: IconPoint
    public var radius: Double

    public init(id: PrimitiveID = PrimitiveID(),
                attributes: PrimitiveAttributes = .default,
                center: IconPoint,
                radius: Double) {
        self.id = id
        self.attributes = attributes
        self.center = center
        self.radius = radius
    }

    public var bounds: IconRect {
        IconRect(x: center.x - radius,
                 y: center.y - radius,
                 width: radius * 2,
                 height: radius * 2)
    }
}

/// A rectangle with uniform corner rounding.
public struct RoundedRectPrimitive: Codable, Hashable, Sendable, Identifiable {

    public var id: PrimitiveID
    public var attributes: PrimitiveAttributes
    public var bounds: IconRect
    public var cornerRadius: Double

    public init(id: PrimitiveID = PrimitiveID(),
                attributes: PrimitiveAttributes = .default,
                bounds: IconRect,
                cornerRadius: Double) {
        self.id = id
        self.attributes = attributes
        self.bounds = bounds
        self.cornerRadius = cornerRadius
    }

    /// The corner radius clamped so opposing corners cannot overlap.
    public var effectiveCornerRadius: Double {
        min(cornerRadius, min(bounds.size.width, bounds.size.height) / 2)
    }
}

/// A capsule: a rectangle rounded to a semicircle on its two short ends.
public struct CapsulePrimitive: Codable, Hashable, Sendable, Identifiable {

    public var id: PrimitiveID
    public var attributes: PrimitiveAttributes
    public var bounds: IconRect

    public init(id: PrimitiveID = PrimitiveID(),
                attributes: PrimitiveAttributes = .default,
                bounds: IconRect) {
        self.id = id
        self.attributes = attributes
        self.bounds = bounds
    }

    public var cornerRadius: Double {
        min(bounds.size.width, bounds.size.height) / 2
    }
}

/// A chain of straight segments through an ordered list of points.
public struct PolylinePrimitive: Codable, Hashable, Sendable, Identifiable {

    public var id: PrimitiveID
    public var attributes: PrimitiveAttributes
    public var points: [IconPoint]
    public var isClosed: Bool

    /// Whether the points are joined by a smooth biarc spline rather than
    /// straight segments. The points are the same either way — only the curve
    /// between them differs — so a smooth path reuses all the polyline
    /// machinery for selection, handles and editing. See ``Biarc`` and §10.5.
    public var isSmooth: Bool

    /// Per-point smoothness, 0 (sharp corner) to 1 (fully round), parallel to
    /// ``points``. Only meaningful when ``isSmooth``. Empty or short means the
    /// missing points are fully round.
    public var pointSmoothness: [Double]

    public init(id: PrimitiveID = PrimitiveID(),
                attributes: PrimitiveAttributes = .default,
                points: [IconPoint],
                isClosed: Bool = false,
                isSmooth: Bool = false,
                pointSmoothness: [Double] = []) {
        self.id = id
        self.attributes = attributes
        self.points = points
        self.isClosed = isClosed
        self.isSmooth = isSmooth
        self.pointSmoothness = pointSmoothness
    }

    /// The smoothness of one point, defaulting to fully round.
    public func smoothness(at index: Int) -> Double {
        guard index >= 0, index < pointSmoothness.count else { return 1 }
        return pointSmoothness[index]
    }

    /// Sets one point's smoothness, growing the array to fit if needed.
    public mutating func setSmoothness(_ value: Double, at index: Int) {
        guard points.indices.contains(index) else { return }
        if pointSmoothness.count < points.count {
            pointSmoothness += Array(repeating: 1,
                                     count: points.count - pointSmoothness.count)
        }
        pointSmoothness[index] = min(1, max(0, value))
    }

    private enum CodingKeys: String, CodingKey {
        case id, attributes, points, isClosed, isSmooth, pointSmoothness
    }

    /// Decodes polylines written before the smooth flag, which are straight.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(PrimitiveID.self, forKey: .id)
        attributes = try container.decode(PrimitiveAttributes.self, forKey: .attributes)
        points = try container.decode([IconPoint].self, forKey: .points)
        isClosed = try container.decode(Bool.self, forKey: .isClosed)
        isSmooth = try container.decodeIfPresent(Bool.self, forKey: .isSmooth) ?? false
        pointSmoothness = try container.decodeIfPresent(
            [Double].self, forKey: .pointSmoothness) ?? []
    }
}

/// A path defined by one half plus a mirror axis.
///
/// Storing symmetry as structure rather than as duplicated geometry means the
/// two halves cannot drift apart. See spec 6.1.
public struct SymmetricPathPrimitive: Codable, Hashable, Sendable, Identifiable {

    public var id: PrimitiveID
    public var attributes: PrimitiveAttributes

    /// The authored half of the path.
    public var points: [IconPoint]

    public var axis: SymmetryAxis

    /// The position of the mirror axis, in units along the axis's normal.
    public var axisPosition: Double

    public init(id: PrimitiveID = PrimitiveID(),
                attributes: PrimitiveAttributes = .default,
                points: [IconPoint],
                axis: SymmetryAxis,
                axisPosition: Double) {
        self.id = id
        self.attributes = attributes
        self.points = points
        self.axis = axis
        self.axisPosition = axisPosition
    }

    /// The authored points reflected across the axis, in reverse order so the
    /// two halves join into one continuous contour.
    public var mirroredPoints: [IconPoint] {
        points.reversed().map { point in
            switch axis {
            case .vertical:
                IconPoint(x: 2 * axisPosition - point.x, y: point.y)
            case .horizontal:
                IconPoint(x: point.x, y: 2 * axisPosition - point.y)
            }
        }
    }
}

public enum SymmetryAxis: String, Codable, Sendable {
    case vertical
    case horizontal
}

/// Geometry imported from an SVG that has not been converted to a semantic
/// primitive.
///
/// Imported artwork always lands here first. Conversion is an explicit user
/// action, never automatic, so import cannot silently rewrite a designer's
/// geometry. See spec 14.3.
public struct ImportedPathPrimitive: Codable, Hashable, Sendable, Identifiable {

    public var id: PrimitiveID
    public var attributes: PrimitiveAttributes

    /// The path data exactly as it appeared in the source SVG.
    public var pathData: String

    /// The group or element the path came from, retained so the exporter can
    /// put it back where it belongs.
    public var sourceElementID: String?

    /// The extent of the path data.
    ///
    /// Recorded at import because this module has no SVG parser and cannot
    /// derive it later. Without it an imported path has no bounds, which makes
    /// it unselectable and invisible to anything that needs to know where the
    /// artwork is.
    public var bounds: IconRect?

    public init(id: PrimitiveID = PrimitiveID(),
                attributes: PrimitiveAttributes = .default,
                pathData: String,
                sourceElementID: String? = nil,
                bounds: IconRect? = nil) {
        self.id = id
        self.attributes = attributes
        self.pathData = pathData
        self.sourceElementID = sourceElementID
        self.bounds = bounds
    }
}

/// A boolean combination of other primitives.
///
/// The children remain independently editable; only the resolved path is
/// derived. See spec 10.4.
public struct CompoundPrimitive: Codable, Hashable, Sendable, Identifiable {

    public var id: PrimitiveID
    public var attributes: PrimitiveAttributes
    public var operation: CompoundOperation
    public var children: [PrimitiveID]

    public init(id: PrimitiveID = PrimitiveID(),
                attributes: PrimitiveAttributes = .default,
                operation: CompoundOperation,
                children: [PrimitiveID]) {
        self.id = id
        self.attributes = attributes
        self.operation = operation
        self.children = children
    }
}

public enum CompoundOperation: String, Codable, Sendable {
    case union
    case subtract
    case intersect
}
