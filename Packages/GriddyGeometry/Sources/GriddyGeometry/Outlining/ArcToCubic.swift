//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// A cubic Bézier segment, as SVG path data expresses curves.
public struct CubicSegment: Hashable, Sendable {

    public var start: IconPoint
    public var control1: IconPoint
    public var control2: IconPoint
    public var end: IconPoint

    public init(start: IconPoint,
                control1: IconPoint,
                control2: IconPoint,
                end: IconPoint) {
        self.start = start
        self.control1 = control1
        self.control2 = control2
        self.end = end
    }

    /// The point at parameter `t`, for checking the approximation.
    public func point(at t: Double) -> IconPoint {
        let u = 1 - t
        let a = u * u * u
        let b = 3 * u * u * t
        let c = 3 * u * t * t
        let d = t * t * t
        return IconPoint(
            x: a * start.x + b * control1.x + c * control2.x + d * end.x,
            y: a * start.y + b * control1.y + c * control2.y + d * end.y
        )
    }
}

/// Converts circular arcs into cubic Béziers.
///
/// Griddy works internally in lines and circular arcs, which is what keeps
/// boolean intersection analytic (§10.5). SVG path data can express elliptical
/// arcs with `A`, but Apple's templates use only `M`, `L`, `C` and `Z`, and
/// Griddy's own importer refuses `A` rather than approximating it. Export
/// therefore converts arcs here, at the last possible moment, where the error
/// is bounded and measurable.
public enum ArcToCubic {

    /// The largest sweep approximated by a single cubic.
    ///
    /// A quarter turn is the usual choice: the maximum radial error of the
    /// standard approximation is about 0.027% of the radius at 90 degrees, and
    /// grows sharply beyond it.
    public static let maximumSweepPerSegment: Double = .pi / 2

    /// How many cubics an arc needs to stay within tolerance.
    public static func segmentCount(for arc: ArcSegment) -> Int {
        max(1, Int(ceil(arc.sweep / maximumSweepPerSegment)))
    }

    /// Approximates an arc as a chain of cubics.
    ///
    /// `count` overrides the number of pieces. Export needs that: reconciled
    /// masters agree on outline segments, but a segment's *cubic* count follows
    /// its sweep, so corresponding arcs of slightly different sweep would
    /// expand into different numbers of commands and undo the reconciliation.
    /// Subdividing further than necessary costs nodes but never accuracy.
    public static func cubics(for arc: ArcSegment, count: Int? = nil) -> [CubicSegment] {
        let sweep = arc.sweep
        guard sweep > 1e-12, arc.radius > 1e-12 else {
            return []
        }

        let count = max(1, count ?? segmentCount(for: arc))
        let step = sweep / Double(count)
        let signedStep = arc.isClockwise ? -step : step

        var segments: [CubicSegment] = []
        var angle = arc.startAngle.radians

        for _ in 0..<count {
            let next = angle + signedStep
            segments.append(cubic(center: arc.center,
                                  radius: arc.radius,
                                  from: angle,
                                  to: next))
            angle = next
        }
        return segments
    }

    /// One cubic spanning a single arc segment.
    ///
    /// Uses the standard control-point construction: the handles run along the
    /// tangents at each end, with length `4/3 · tan(θ/4) · r`. That value is
    /// what makes the curve pass exactly through the arc's midpoint.
    static func cubic(center: IconPoint,
                      radius: Double,
                      from startAngle: Double,
                      to endAngle: Double) -> CubicSegment {
        let sweep = endAngle - startAngle
        let handle = 4.0 / 3.0 * tan(sweep / 4) * radius

        let start = IconPoint(x: center.x + radius * cos(startAngle),
                              y: center.y + radius * sin(startAngle))
        let end = IconPoint(x: center.x + radius * cos(endAngle),
                            y: center.y + radius * sin(endAngle))

        // Tangent direction at each end, pointing the way the sweep travels.
        let startTangent = IconVector(dx: -sin(startAngle), dy: cos(startAngle))
        let endTangent = IconVector(dx: -sin(endAngle), dy: cos(endAngle))

        return CubicSegment(
            start: start,
            control1: start.offset(by: startTangent.scaled(by: handle)),
            control2: end.offset(by: endTangent.scaled(by: -handle)),
            end: end
        )
    }
}
