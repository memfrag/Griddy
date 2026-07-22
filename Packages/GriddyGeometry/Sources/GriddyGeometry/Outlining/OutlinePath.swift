//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// One piece of an outline.
///
/// Deliberately only lines and circular arcs. Every primitive Griddy supports
/// outlines exactly into these two forms, and restricting the vocabulary this
/// way keeps every curve-curve intersection analytic: line/line, line/circle
/// and circle/circle all have closed-form solutions, so the boolean solver
/// never needs numerical root finding. See spec 10.5.
public enum OutlineSegment: Codable, Hashable, Sendable {

    case line(from: IconPoint, to: IconPoint)
    case arc(ArcSegment)

    public var start: IconPoint {
        switch self {
        case .line(let from, _): from
        case .arc(let arc): arc.startPoint
        }
    }

    public var end: IconPoint {
        switch self {
        case .line(_, let to): to
        case .arc(let arc): arc.endPoint
        }
    }

    /// The segment traversed in the opposite direction.
    public var reversed: OutlineSegment {
        switch self {
        case .line(let from, let to):
            .line(from: to, to: from)
        case .arc(let arc):
            .arc(arc.reversed)
        }
    }

    /// The segment's arc length.
    ///
    /// Used to parameterise contours by distance travelled, which is how
    /// corresponding positions are found across masters.
    public var length: Double {
        switch self {
        case .line(let from, let to):
            from.distance(to: to)
        case .arc(let arc):
            arc.radius * arc.sweep
        }
    }

    /// The exact distance from a point to this segment.
    ///
    /// Analytic rather than sampled, because the segments are only ever lines
    /// and circular arcs. Sampling would bound the answer by the sample
    /// spacing, which is misleading precisely when the distance is small.
    public func distance(to point: IconPoint) -> Double {
        switch self {
        case .line(let from, let to):
            return PrimitiveGeometry.distance(from: point, toSegmentFrom: from, to: to)

        case .arc(let arc):
            let radial = arc.center.vector(to: point)
            guard radial.length > .ulpOfOne else {
                return arc.radius
            }
            let angle = IconAngle(radians: atan2(radial.dy, radial.dx))
            if arc.parameter(atAngle: angle) != nil {
                return abs(radial.length - arc.radius)
            }
            return min(point.distance(to: arc.startPoint),
                       point.distance(to: arc.endPoint))
        }
    }

    /// The parameter at which this segment reaches its smallest x, and that x.
    ///
    /// The leftmost point is a stable landmark: it moves continuously as stroke
    /// width changes, so it survives as a correspondence anchor between masters
    /// where a vertex index would not.
    var leftmostExtreme: (parameter: Double, x: Double) {
        switch self {
        case .line(let from, let to):
            from.x <= to.x ? (0, from.x) : (1, to.x)

        case .arc(let arc):
            {
                // A circle's leftmost point is at 180 degrees, if the sweep
                // reaches it; otherwise an endpoint is the extreme.
                let west = IconAngle(radians: .pi)
                if let t = arc.parameter(atAngle: west) {
                    return (t, arc.center.x - arc.radius)
                }
                let start = arc.startPoint, end = arc.endPoint
                return start.x <= end.x ? (0, start.x) : (1, end.x)
            }()
        }
    }

    /// This segment's contribution to the contour's signed area.
    ///
    /// The shoelace term for the chord, plus the area of the circular segment
    /// the arc bulges out by. Summing this over a closed contour gives twice
    /// the signed area, positive when the contour runs counterclockwise.
    var signedAreaContribution: Double {
        let chord = start.x * end.y - end.x * start.y

        switch self {
        case .line:
            return chord
        case .arc(let arc):
            let sweep = arc.sweep
            let bulge = arc.radius * arc.radius * (sweep - sin(sweep))
            return chord + (arc.isClockwise ? -bulge : bulge)
        }
    }
}

/// A circular arc segment of an outline.
public struct ArcSegment: Codable, Hashable, Sendable {

    public var center: IconPoint
    public var radius: Double
    public var startAngle: IconAngle
    public var endAngle: IconAngle
    public var isClockwise: Bool

    public init(center: IconPoint,
                radius: Double,
                startAngle: IconAngle,
                endAngle: IconAngle,
                isClockwise: Bool = false) {
        self.center = center
        self.radius = radius
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.isClockwise = isClockwise
    }

    public func point(atAngle angle: IconAngle) -> IconPoint {
        center.offset(by: angle.direction.scaled(by: radius))
    }

    public var startPoint: IconPoint { point(atAngle: startAngle) }
    public var endPoint: IconPoint { point(atAngle: endAngle) }

    /// The angular extent, always positive.
    public var sweep: Double {
        let turn = 2 * Double.pi
        let raw = isClockwise
            ? startAngle.radians - endAngle.radians
            : endAngle.radians - startAngle.radians

        var value = raw.truncatingRemainder(dividingBy: turn)
        if value < 0 {
            value += turn
        }
        return value == 0 ? turn : value
    }

    public var reversed: ArcSegment {
        ArcSegment(center: center,
                   radius: radius,
                   startAngle: endAngle,
                   endAngle: startAngle,
                   isClockwise: !isClockwise)
    }
}

/// A closed loop of segments.
public struct OutlineContour: Codable, Hashable, Sendable {

    public var segments: [OutlineSegment]

    public init(segments: [OutlineSegment]) {
        self.segments = segments
    }

    /// Signed area: positive counterclockwise, negative clockwise.
    ///
    /// Orientation carries meaning: an outer boundary runs counterclockwise and
    /// a hole runs clockwise, which is what makes nested contours fill
    /// correctly.
    public var signedArea: Double {
        segments.reduce(0) { $0 + $1.signedAreaContribution } / 2
    }

    public var area: Double {
        abs(signedArea)
    }

    public var isCounterclockwise: Bool {
        signedArea > 0
    }

    /// The contour traversed the other way round, flipping its orientation.
    public var reversed: OutlineContour {
        OutlineContour(segments: segments.reversed().map(\.reversed))
    }

    /// The contour forced to a given orientation.
    public func oriented(counterclockwise: Bool) -> OutlineContour {
        isCounterclockwise == counterclockwise ? self : reversed
    }

    /// Total arc length around the contour.
    public var length: Double {
        segments.reduce(0) { $0 + $1.length }
    }

    /// The average of the segment start points.
    ///
    /// A cheap stand-in for the area centroid, and sufficient for matching
    /// contours between masters that differ only by stroke width.
    public var averagePoint: IconPoint {
        guard !segments.isEmpty else {
            return .zero
        }
        let sum = segments.reduce(IconPoint.zero) { total, segment in
            IconPoint(x: total.x + segment.start.x, y: total.y + segment.start.y)
        }
        return IconPoint(x: sum.x / Double(segments.count),
                         y: sum.y / Double(segments.count))
    }

    /// Whether each segment starts where the previous one ended.
    ///
    /// A contour that fails this is not closed, and anything downstream --
    /// filling, boolean resolution, export -- will produce nonsense from it.
    public func isConnected(tolerance: Double = 1e-9) -> Bool {
        guard segments.count > 1 else {
            return !segments.isEmpty
        }
        for index in segments.indices {
            let current = segments[index]
            let next = segments[(index + 1) % segments.count]
            if current.end.distance(to: next.start) > tolerance {
                return false
            }
        }
        return true
    }
}

/// A complete outline: one or more closed contours.
///
/// A stroked circle produces two -- the outer boundary and the hole.
public struct OutlinePath: Codable, Hashable, Sendable {

    public var contours: [OutlineContour]

    public static let empty = OutlinePath(contours: [])

    public init(contours: [OutlineContour]) {
        self.contours = contours
    }

    public var isEmpty: Bool {
        contours.isEmpty
    }

    /// Total enclosed area, treating clockwise contours as holes.
    public var area: Double {
        contours.reduce(0) { $0 + $1.signedArea }
    }

    public var segmentCount: Int {
        contours.reduce(0) { $0 + $1.segments.count }
    }
}
