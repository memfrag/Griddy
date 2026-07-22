//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// Exact bounds for outlines.
///
/// Exact, not approximate: the extremes are found analytically rather than by
/// sampling. An arc reaches its extreme x where it crosses angle 0 or pi, and
/// its extreme y at pi/2 or 3pi/2 -- but only if the arc actually sweeps
/// through that angle. Endpoints supply the rest.
///
/// This matters because the bounds set the exported symbol's advance width
/// (spec 9.5), and a bound that is too small by a fraction of a unit shows up
/// as a symbol that crowds the text beside it.
public extension ArcSegment {

    /// Whether the arc sweeps through the given angle.
    func sweeps(through angle: Double) -> Bool {
        let full = 2 * Double.pi
        // Angle travelled from the start to `angle`, in the arc's own
        // direction, normalised into [0, 2pi).
        var travelled = isClockwise
            ? startAngle.radians - angle
            : angle - startAngle.radians
        travelled = travelled.truncatingRemainder(dividingBy: full)
        if travelled < 0 {
            travelled += full
        }
        return travelled <= sweep + 1e-12
    }

    /// The arc's exact bounding box.
    var bounds: IconRect {
        var xs = [startPoint.x, endPoint.x]
        var ys = [startPoint.y, endPoint.y]

        // The four compass extremes, each counted only if swept through.
        for (angle, isHorizontal) in [(0.0, true), (Double.pi, true),
                                      (Double.pi / 2, false),
                                      (3 * Double.pi / 2, false)] {
            guard sweeps(through: angle) else {
                continue
            }
            if isHorizontal {
                xs.append(center.x + radius * cos(angle))
            } else {
                ys.append(center.y + radius * sin(angle))
            }
        }

        let minX = xs.min() ?? 0, maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0, maxY = ys.max() ?? 0
        return IconRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

public extension OutlineSegment {

    var bounds: IconRect {
        switch self {
        case .line(let from, let to):
            IconRect(x: Swift.min(from.x, to.x),
                     y: Swift.min(from.y, to.y),
                     width: abs(to.x - from.x),
                     height: abs(to.y - from.y))
        case .arc(let arc):
            arc.bounds
        }
    }
}

public extension OutlineContour {

    var bounds: IconRect? {
        segments.map(\.bounds).reduce(nil) { $0?.union($1) ?? $1 }
    }
}

public extension OutlinePath {

    /// The outline's exact bounding box, or nil when it has no geometry.
    var bounds: IconRect? {
        contours.compactMap(\.bounds).reduce(nil) { $0?.union($1) ?? $1 }
    }
}
