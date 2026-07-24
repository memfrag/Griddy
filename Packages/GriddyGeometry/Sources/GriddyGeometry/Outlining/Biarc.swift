//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// Fits a smooth curve through points as a chain of circular arcs.
///
/// Griddy works in lines and circular arcs so that intersection stays
/// closed-form (§10.5). A smooth curve is therefore not a cubic Bézier — which
/// would break that — but a *biarc spline*: through each pair of points runs a
/// pair of circular arcs that meet tangentially, and the tangent is continuous
/// across the points too, so the whole path is smooth (G1) yet still made of
/// arcs the outliner and boolean solver already handle exactly.
public enum Biarc {

    /// The centerline through the points, as arcs and lines.
    ///
    /// Fewer than two points has no curve. Two points with no bend is a single
    /// line. A run of collinear points degenerates to lines rather than arcs of
    /// enormous radius.
    ///
    /// - Parameter smoothness: per-point, 0 to 1. At 1 the curve flows smoothly
    ///   through the point (a rounded corner); at 0 the point is sharp — its
    ///   tangents fall onto the chords, so its arcs collapse to straight lines
    ///   meeting at a kink. Values outside the array's range default to 1.
    public static func fit(through points: [IconPoint],
                           closed: Bool,
                           smoothness: [Double] = []) -> [OutlineSegment] {
        guard points.count >= 2 else {
            return []
        }

        let (outgoing, incoming) = tangents(points, closed: closed,
                                            smoothness: smoothness)

        var segments: [OutlineSegment] = []
        let pairCount = closed ? points.count : points.count - 1
        for index in 0..<pairCount {
            let next = (index + 1) % points.count
            segments.append(contentsOf: biarc(points[index], outgoing[index],
                                              points[next], incoming[next]))
        }
        return segments
    }

    // MARK: Tangents

    /// The tangent leaving each point and the tangent arriving at it.
    ///
    /// Smooth points share one tangent (Catmull-Rom, so the join is continuous);
    /// a sharp point instead aims each side straight at its neighbour, and the
    /// smoothness blends between the two. Splitting into leaving/arriving is what
    /// lets a single point be a corner: its two sides then point different ways.
    static func tangents(_ points: [IconPoint],
                         closed: Bool,
                         smoothness: [Double]) -> (out: [IconVector], in: [IconVector]) {
        let count = points.count
        func smooth(_ index: Int) -> Double {
            guard index >= 0, index < smoothness.count else { return 1 }
            return min(1, max(0, smoothness[index]))
        }
        func lerp(_ a: IconVector, _ b: IconVector, _ t: Double) -> IconVector {
            IconVector(dx: a.dx + (b.dx - a.dx) * t, dy: a.dy + (b.dy - a.dy) * t)
        }
        let fallback = IconVector(dx: 1, dy: 0)

        var outgoing = [IconVector](repeating: fallback, count: count)
        var incoming = [IconVector](repeating: fallback, count: count)

        for index in 0..<count {
            let hasPrev = closed || index > 0
            let hasNext = closed || index < count - 1
            let prev = points[(index - 1 + count) % count]
            let next = points[(index + 1) % count]

            let toNext = hasNext ? points[index].vector(to: next).normalized : nil
            let fromPrev = hasPrev ? prev.vector(to: points[index]).normalized : nil

            // The smooth tangent runs neighbour to neighbour; at an open end it
            // is whatever single chord exists.
            let catmull = (fromPrev.map { fp in
                toNext.map { tn in
                    IconVector(dx: fp.dx + tn.dx, dy: fp.dy + tn.dy).normalized
                } ?? fp
            } ?? toNext) ?? fallback

            let s = smooth(index)
            outgoing[index] = (lerp(toNext ?? catmull, catmull, s).normalized) ?? catmull
            incoming[index] = (lerp(fromPrev ?? catmull, catmull, s).normalized) ?? catmull
        }
        return (outgoing, incoming)
    }

    // MARK: Biarc

    /// The pair of arcs joining two points with given tangents.
    static func biarc(_ p0: IconPoint, _ t0: IconVector,
                      _ p1: IconPoint, _ t1: IconVector) -> [OutlineSegment] {
        let chord = p0.distance(to: p1)
        guard chord > 1e-9 else {
            return []
        }

        // Control points a third of the chord along each tangent, joined at
        // their midpoint. The midpoint join is what guarantees the two arcs
        // share a tangent there, for any handle length; a third of the chord is
        // the familiar Bézier-like amount that keeps the curve taut.
        let handle = chord / 3
        let q0 = p0.offset(by: t0.scaled(by: handle))
        let q1 = p1.offset(by: t1.scaled(by: -handle))
        let joint = IconPoint(x: (q0.x + q1.x) / 2, y: (q0.y + q1.y) / 2)

        let first = arc(from: p0, tangent: t0, to: joint)
        // The second arc runs from the joint to p1, tangent t1 at p1. Build it
        // from p1 backwards and reverse, so the tangent condition is at p1.
        let second = arc(from: p1, tangent: t1.scaled(by: -1), to: joint).reversed

        // A sharp segment (both tangents on the chord) collapses to two
        // collinear lines through the joint; merge them into one so a
        // straight-cornered path carries no redundant midpoints.
        if case .line = first, case .line = second, collinear(p0, joint, p1) {
            return [.line(from: p0, to: p1)]
        }
        return [first, second]
    }

    /// The arc leaving `a` in direction `tangent` and ending at `b`, or a line
    /// when the three are collinear.
    static func arc(from a: IconPoint, tangent: IconVector,
                    to b: IconPoint) -> OutlineSegment {
        guard let unitTangent = tangent.normalized else {
            return .line(from: a, to: b)
        }
        let normal = unitTangent.perpendicular
        let ab = a.vector(to: b)
        let denom = 2 * (ab.dx * normal.dx + ab.dy * normal.dy)

        // The centre lies on the normal at `a`, equidistant from `a` and `b`.
        // A near-zero denominator means `b` lies along the tangent: a line.
        guard abs(denom) > 1e-9 else {
            return .line(from: a, to: b)
        }
        let signedRadius = (ab.dx * ab.dx + ab.dy * ab.dy) / denom
        let center = a.offset(by: normal.scaled(by: signedRadius))
        let radius = abs(signedRadius)

        let startAngle = angle(from: center, to: a)
        let endAngle = angle(from: center, to: b)

        // The arc must leave `a` heading along the tangent. The counterclockwise
        // tangent at `a` is the radius turned a quarter turn; if that agrees with
        // the tangent the sweep is counterclockwise, otherwise clockwise.
        let radial = center.vector(to: a)
        let ccwTangent = IconVector(dx: -radial.dy, dy: radial.dx)
        let isClockwise = (ccwTangent.dx * unitTangent.dx
                           + ccwTangent.dy * unitTangent.dy) < 0

        return .arc(ArcSegment(center: center,
                               radius: radius,
                               startAngle: startAngle,
                               endAngle: endAngle,
                               isClockwise: isClockwise))
    }

    private static func angle(from center: IconPoint, to point: IconPoint) -> IconAngle {
        IconAngle(radians: atan2(point.y - center.y, point.x - center.x))
    }

    /// Whether three points lie on one line, with `b` between `a` and `c`.
    private static func collinear(_ a: IconPoint, _ b: IconPoint,
                                  _ c: IconPoint) -> Bool {
        let ab = a.vector(to: b)
        let bc = b.vector(to: c)
        let cross = ab.dx * bc.dy - ab.dy * bc.dx
        let dot = ab.dx * bc.dx + ab.dy * bc.dy
        return abs(cross) < 1e-9 && dot > 0
    }
}
