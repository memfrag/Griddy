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
    public static func fit(through points: [IconPoint],
                           closed: Bool) -> [OutlineSegment] {
        guard points.count >= 2 else {
            return []
        }

        let tangents = estimateTangents(points, closed: closed)

        var segments: [OutlineSegment] = []
        let pairCount = closed ? points.count : points.count - 1
        for index in 0..<pairCount {
            let next = (index + 1) % points.count
            segments.append(contentsOf: biarc(points[index], tangents[index],
                                              points[next], tangents[next]))
        }
        return segments
    }

    // MARK: Tangents

    /// A unit tangent at each point, estimated from its neighbours.
    ///
    /// An interior point points along the line joining its neighbours
    /// (Catmull-Rom style), which is what makes the tangent continuous across
    /// the point and so the whole spline smooth. Open endpoints aim at their one
    /// neighbour.
    static func estimateTangents(_ points: [IconPoint],
                                 closed: Bool) -> [IconVector] {
        let count = points.count
        return points.indices.map { index in
            let previous: IconPoint
            let next: IconPoint
            if closed {
                previous = points[(index - 1 + count) % count]
                next = points[(index + 1) % count]
            } else if index == 0 {
                previous = points[0]
                next = points[1]
            } else if index == count - 1 {
                previous = points[count - 2]
                next = points[count - 1]
            } else {
                previous = points[index - 1]
                next = points[index + 1]
            }
            return previous.vector(to: next).normalized
                ?? IconVector(dx: 1, dy: 0)
        }
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
}
