//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// Whether a point lies inside an outline.
///
/// Uses the winding number rather than a parity count, because outlines
/// represent holes by orientation: a ring's inner contour runs clockwise, so
/// its interior must come out with winding zero even though a ray crosses two
/// contours to reach it.
public enum PointContainment {

    /// The winding number of a path around a point.
    ///
    /// Counts signed crossings of a ray travelling in +x. Upward crossings
    /// count +1 and downward -1, so a counterclockwise contour gives +1 for
    /// points inside it and a clockwise one gives -1.
    public static func windingNumber(of path: OutlinePath,
                                     around point: IconPoint) -> Int {
        path.contours.reduce(0) { $0 + windingNumber(of: $1, around: point) }
    }

    public static func windingNumber(of contour: OutlineContour,
                                     around point: IconPoint) -> Int {
        contour.segments.reduce(0) { $0 + crossings(of: $1, rightOf: point) }
    }

    /// Whether a point is inside, by the non-zero rule.
    public static func contains(_ path: OutlinePath, _ point: IconPoint) -> Bool {
        windingNumber(of: path, around: point) != 0
    }

    // MARK: Ray crossings

    private static let epsilon = 1e-12

    private static func crossings(of segment: OutlineSegment,
                                  rightOf point: IconPoint) -> Int {
        switch segment {
        case .line(let from, let to):
            lineCrossings(from, to, rightOf: point)
        case .arc(let arc):
            arcCrossings(arc, rightOf: point)
        }
    }

    private static func lineCrossings(_ from: IconPoint,
                                      _ to: IconPoint,
                                      rightOf point: IconPoint) -> Int {
        // Half-open in y so a vertex shared by two segments is counted once,
        // rather than twice or not at all.
        let upward = from.y <= point.y && to.y > point.y
        let downward = to.y <= point.y && from.y > point.y

        guard upward || downward else {
            return 0
        }

        let dy = to.y - from.y
        guard abs(dy) > epsilon else {
            return 0
        }

        let t = (point.y - from.y) / dy
        let x = from.x + (to.x - from.x) * t
        guard x > point.x else {
            return 0
        }
        return upward ? 1 : -1
    }

    private static func arcCrossings(_ arc: ArcSegment,
                                     rightOf point: IconPoint) -> Int {
        // Where does the circle reach the ray's height?
        let dy = point.y - arc.center.y
        guard arc.radius > epsilon, abs(dy) <= arc.radius else {
            return 0
        }

        let base = asin(max(-1, min(1, dy / arc.radius)))
        // Two angles share a y value: one on the right of the circle and one on
        // the left.
        let angles = [base, Double.pi - base]

        var total = 0
        for candidate in angles {
            let angle = IconAngle(radians: candidate)

            guard let t = arc.parameter(atAngle: angle) else {
                continue
            }

            // Exclude the very end of a segment so a shared vertex is counted
            // once across the two segments that meet there.
            guard t > -epsilon, t < 1 - 1e-9 else {
                continue
            }

            let x = arc.center.x + arc.radius * cos(candidate)
            guard x > point.x else {
                continue
            }

            // Travelling counterclockwise, y increases where cos is positive.
            let ascending = cos(candidate) > 0
            let travellingForward = !arc.isClockwise
            total += (ascending == travellingForward) ? 1 : -1
        }
        return total
    }
}
