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
    /// - Parameters:
    ///   - inSmoothness: per-point smoothness for the *arriving* side, 0 to 1.
    ///   - outSmoothness: per-point smoothness for the *leaving* side. Splitting
    ///     the two is what makes a side independently sharp or round: at 1 that
    ///     side flows smoothly, at 0 its tangent falls onto the chord and its
    ///     arc collapses to a line into a kink. Missing values default to 1.
    public static func fit(through points: [IconPoint],
                           closed: Bool,
                           inSmoothness: [Double] = [],
                           outSmoothness: [Double] = [],
                           handles: [CurveHandle?] = []) -> [OutlineSegment] {
        guard points.count >= 2 else {
            return []
        }

        // Every segment is the cubic between two points and their handles,
        // matched by arcs. A round point has a handle along its tangent; a sharp
        // one has none, so its side is a straight chord; a free point has an
        // arbitrary handle. One mechanism covers all three.
        let (out, incoming) = handleOffsets(points, closed: closed,
                                            inSmoothness: inSmoothness,
                                            outSmoothness: outSmoothness,
                                            handles: handles)

        var segments: [OutlineSegment] = []
        let pairCount = closed ? points.count : points.count - 1
        for index in 0..<pairCount {
            let next = (index + 1) % points.count
            let c0 = points[index].offset(by: out[index])
            let c1 = points[next].offset(by: incoming[next])
            segments.append(contentsOf:
                approximateCubic(points[index], c0, c1, points[next]))
        }
        return segments
    }

    /// Convenience for a symmetric smoothness applied to both sides.
    public static func fit(through points: [IconPoint],
                           closed: Bool,
                           smoothness: [Double]) -> [OutlineSegment] {
        fit(through: points, closed: closed,
            inSmoothness: smoothness, outSmoothness: smoothness)
    }

    // MARK: Handles

    /// The control-point offset from each point on its arriving and leaving
    /// sides — the tangent handles.
    ///
    /// A free point uses its explicit handles. Otherwise the handle runs along
    /// the point's smooth (Catmull-Rom) tangent, and its length is the
    /// smoothness times a third of the adjacent chord: at 1 a full round handle,
    /// at 0 nothing, so the side runs straight into a corner.
    public static func handleOffsets(_ points: [IconPoint], closed: Bool,
                                     inSmoothness: [Double], outSmoothness: [Double],
                                     handles: [CurveHandle?])
    -> (out: [IconVector], in: [IconVector]) {
        let count = points.count
        func clamp(_ array: [Double], _ index: Int) -> Double {
            guard index >= 0, index < array.count else { return 1 }
            return min(1, max(0, array[index]))
        }
        func explicit(_ index: Int) -> CurveHandle? {
            guard index >= 0, index < handles.count else { return nil }
            return handles[index]
        }
        let tangents = catmullTangents(points, closed: closed)

        var out = [IconVector](repeating: .zero, count: count)
        var incoming = [IconVector](repeating: .zero, count: count)
        for index in 0..<count {
            if let handle = explicit(index) {
                out[index] = handle.outOffset
                incoming[index] = handle.inOffset
                continue
            }
            let prev = points[(index - 1 + count) % count]
            let next = points[(index + 1) % count]
            let chordNext = (closed || index < count - 1)
                ? points[index].distance(to: next) : 0
            let chordPrev = (closed || index > 0)
                ? prev.distance(to: points[index]) : 0
            let tangent = tangents[index]
            out[index] = tangent.scaled(by: clamp(outSmoothness, index) * chordNext / 3)
            incoming[index] = tangent.scaled(by: -clamp(inSmoothness, index) * chordPrev / 3)
        }
        return (out, incoming)
    }

    /// A unit smooth tangent at each point, along the line joining its
    /// neighbours; at an open end, along its single chord.
    static func catmullTangents(_ points: [IconPoint],
                                closed: Bool) -> [IconVector] {
        let count = points.count
        let fallback = IconVector(dx: 1, dy: 0)
        return points.indices.map { index in
            let hasPrev = closed || index > 0
            let hasNext = closed || index < count - 1
            let prev = points[(index - 1 + count) % count]
            let next = points[(index + 1) % count]
            let toNext = hasNext ? points[index].vector(to: next).normalized : nil
            let fromPrev = hasPrev ? prev.vector(to: points[index]).normalized : nil
            if let fp = fromPrev, let tn = toNext {
                return IconVector(dx: fp.dx + tn.dx, dy: fp.dy + tn.dy).normalized ?? fp
            }
            return toNext ?? fromPrev ?? fallback
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

    // MARK: Cubic approximation

    /// Approximates a cubic Bézier with a chain of circular arcs.
    ///
    /// This is how free tangent handles stay arc-based: the handles define a
    /// cubic, and the cubic is matched by arcs to a tolerance rather than kept
    /// as a cubic the boolean solver could not intersect. A biarc is fitted to
    /// the cubic's endpoints and end tangents; where it strays too far the cubic
    /// is split in half and each half fitted, recursively, so curvature gets as
    /// many arcs as it needs and a gentle curve gets few.
    public static func approximateCubic(_ p0: IconPoint, _ c0: IconPoint,
                                        _ c1: IconPoint, _ p1: IconPoint,
                                        tolerance: Double = 0.02,
                                        depth: Int = 0) -> [OutlineSegment] {
        // A degenerate handle (control point on its anchor) falls back to the
        // chord, so a point with no handle on a side runs straight into the
        // corner there.
        let chord = p0.vector(to: p1).normalized ?? IconVector(dx: 1, dy: 0)
        let startTangent = p0.vector(to: c0).normalized ?? chord
        let endTangent = c1.vector(to: p1).normalized ?? chord

        let pieces = biarc(p0, startTangent, p1, endTangent)

        // Deep enough, or the biarc already tracks the cubic: accept it.
        if depth >= 8 || fits(pieces, cubic: (p0, c0, c1, p1), tolerance: tolerance) {
            return pieces
        }

        let (left, right) = splitCubic(p0, c0, c1, p1)
        return approximateCubic(left.0, left.1, left.2, left.3,
                                tolerance: tolerance, depth: depth + 1)
            + approximateCubic(right.0, right.1, right.2, right.3,
                               tolerance: tolerance, depth: depth + 1)
    }


    /// Whether the arcs stay within tolerance of the cubic at sample points.
    private static func fits(_ pieces: [OutlineSegment],
                             cubic: (IconPoint, IconPoint, IconPoint, IconPoint),
                             tolerance: Double) -> Bool {
        for step in 1...3 {
            let t = Double(step) / 4
            let point = cubicPoint(cubic.0, cubic.1, cubic.2, cubic.3, at: t)
            let nearest = pieces.map { $0.distance(to: point) }.min() ?? .infinity
            if nearest > tolerance {
                return false
            }
        }
        return true
    }

    static func cubicPoint(_ p0: IconPoint, _ c0: IconPoint, _ c1: IconPoint,
                           _ p1: IconPoint, at t: Double) -> IconPoint {
        let u = 1 - t
        let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
        return IconPoint(x: a * p0.x + b * c0.x + c * c1.x + d * p1.x,
                         y: a * p0.y + b * c0.y + c * c1.y + d * p1.y)
    }

    /// Splits a cubic at its midpoint (de Casteljau).
    private static func splitCubic(_ p0: IconPoint, _ c0: IconPoint,
                                   _ c1: IconPoint, _ p1: IconPoint)
    -> (left: (IconPoint, IconPoint, IconPoint, IconPoint),
        right: (IconPoint, IconPoint, IconPoint, IconPoint)) {
        func mid(_ a: IconPoint, _ b: IconPoint) -> IconPoint {
            IconPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }
        let a = mid(p0, c0), b = mid(c0, c1), e = mid(c1, p1)
        let d = mid(a, b), f = mid(b, e)
        let g = mid(d, f)
        return ((p0, a, d, g), (g, f, e, p1))
    }
}
