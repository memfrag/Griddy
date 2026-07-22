//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// Where two outline segments cross.
public struct SegmentCrossing: Hashable, Sendable {

    /// Parameter along the first segment.
    public var t: Double

    /// Parameter along the second segment.
    public var u: Double

    public var point: IconPoint
}

/// Analytic intersection of outline segments.
///
/// Every case has a closed form because outlines contain only lines and
/// circular arcs: line/line is a 2x2 solve, line/circle a quadratic, and
/// circle/circle the radical-line construction. No numerical root finding is
/// involved, which is the whole reason the outliner restricts itself to these
/// two segment kinds. See spec 10.5.
public enum SegmentIntersection {

    /// Tolerance for treating a parameter as being within a segment's range.
    static let parameterEpsilon = 1e-9

    /// Tolerance for treating a determinant or radius as degenerate.
    static let geometryEpsilon = 1e-12

    public static func crossings(_ first: OutlineSegment,
                                 _ second: OutlineSegment) -> [SegmentCrossing] {
        switch (first, second) {
        case (.line(let a0, let a1), .line(let b0, let b1)):
            lineLine(a0, a1, b0, b1)

        case (.line(let a0, let a1), .arc(let arc)):
            lineArc(a0, a1, arc, swapped: false)

        case (.arc(let arc), .line(let b0, let b1)):
            lineArc(b0, b1, arc, swapped: true)

        case (.arc(let first), .arc(let second)):
            arcArc(first, second)
        }
    }

    // MARK: Line / line

    private static func lineLine(_ a0: IconPoint, _ a1: IconPoint,
                                 _ b0: IconPoint, _ b1: IconPoint) -> [SegmentCrossing] {
        let da = a0.vector(to: a1)
        let db = b0.vector(to: b1)
        let denominator = da.cross(db)

        // Parallel or collinear. Collinear overlap has infinitely many
        // intersections and is handled as a degenerate case rather than
        // reported here; see the note on BooleanSolver.
        guard abs(denominator) > geometryEpsilon else {
            return []
        }

        let offset = a0.vector(to: b0)
        let t = offset.cross(db) / denominator
        let u = offset.cross(da) / denominator

        guard isWithinUnitRange(t), isWithinUnitRange(u) else {
            return []
        }
        return [SegmentCrossing(t: clampToUnit(t),
                                u: clampToUnit(u),
                                point: IconPoint(x: a0.x + da.dx * t,
                                                 y: a0.y + da.dy * t))]
    }

    // MARK: Line / arc

    private static func lineArc(_ p0: IconPoint,
                                _ p1: IconPoint,
                                _ arc: ArcSegment,
                                swapped: Bool) -> [SegmentCrossing] {
        let direction = p0.vector(to: p1)
        let toStart = arc.center.vector(to: p0)

        let a = direction.dot(direction)
        guard a > geometryEpsilon else {
            return []
        }
        let b = 2 * toStart.dot(direction)
        let c = toStart.dot(toStart) - arc.radius * arc.radius

        let discriminant = b * b - 4 * a * c
        guard discriminant >= 0 else {
            return []
        }

        let root = discriminant.squareRoot()
        let candidates = discriminant < geometryEpsilon
            ? [-b / (2 * a)]                       // tangent: one double root
            : [(-b - root) / (2 * a), (-b + root) / (2 * a)]

        var crossings: [SegmentCrossing] = []
        for lineParameter in candidates where isWithinUnitRange(lineParameter) {
            let point = IconPoint(x: p0.x + direction.dx * lineParameter,
                                  y: p0.y + direction.dy * lineParameter)
            let radial = arc.center.vector(to: point)
            let angle = IconAngle(radians: atan2(radial.dy, radial.dx))

            guard let arcParameter = arc.parameter(atAngle: angle) else {
                continue
            }

            let line = clampToUnit(lineParameter)
            crossings.append(swapped
                ? SegmentCrossing(t: arcParameter, u: line, point: point)
                : SegmentCrossing(t: line, u: arcParameter, point: point))
        }
        return crossings
    }

    // MARK: Arc / arc

    private static func arcArc(_ first: ArcSegment,
                               _ second: ArcSegment) -> [SegmentCrossing] {
        let between = first.center.vector(to: second.center)
        let distance = between.length

        // Concentric circles either never meet or coincide entirely.
        guard distance > geometryEpsilon else {
            return []
        }
        // Too far apart, or one contained within the other.
        guard distance <= first.radius + second.radius + geometryEpsilon,
              distance >= abs(first.radius - second.radius) - geometryEpsilon else {
            return []
        }

        // Radical line construction: the chord through both intersections lies
        // at distance `along` from the first centre.
        let along = (first.radius * first.radius
                     - second.radius * second.radius
                     + distance * distance) / (2 * distance)
        let heightSquared = first.radius * first.radius - along * along
        let height = heightSquared > 0 ? heightSquared.squareRoot() : 0

        guard let unit = between.normalized else {
            return []
        }
        let base = first.center.offset(by: unit.scaled(by: along))
        let perpendicular = unit.perpendicular.scaled(by: height)

        let candidates = height < geometryEpsilon
            ? [base]                                // tangent: a single point
            : [base.offset(by: perpendicular),
               base.offset(by: perpendicular.scaled(by: -1))]

        var crossings: [SegmentCrossing] = []
        for point in candidates {
            let firstRadial = first.center.vector(to: point)
            let secondRadial = second.center.vector(to: point)

            guard let t = first.parameter(atAngle:
                    IconAngle(radians: atan2(firstRadial.dy, firstRadial.dx))),
                  let u = second.parameter(atAngle:
                    IconAngle(radians: atan2(secondRadial.dy, secondRadial.dx))) else {
                continue
            }
            crossings.append(SegmentCrossing(t: t, u: u, point: point))
        }
        return crossings
    }

    // MARK: Helpers

    private static func isWithinUnitRange(_ value: Double) -> Bool {
        value >= -parameterEpsilon && value <= 1 + parameterEpsilon
    }

    private static func clampToUnit(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
