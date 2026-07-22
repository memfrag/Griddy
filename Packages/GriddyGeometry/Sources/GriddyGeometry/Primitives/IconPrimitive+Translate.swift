//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

extension IconPrimitive {

    /// The primitive moved by a vector, preserving identity and attributes.
    ///
    /// Identity must survive an edit, because per-master adjustments are keyed
    /// by it. See spec 10.2.
    public func translated(by vector: IconVector) -> IconPrimitive {
        switch self {
        case .line(var line):
            line.start = line.start.offset(by: vector)
            line.end = line.end.offset(by: vector)
            return .line(line)

        case .arc(var arc):
            arc.center = arc.center.offset(by: vector)
            return .arc(arc)

        case .circle(var circle):
            circle.center = circle.center.offset(by: vector)
            return .circle(circle)

        case .roundedRect(var rect):
            rect.bounds.origin = rect.bounds.origin.offset(by: vector)
            return .roundedRect(rect)

        case .capsule(var capsule):
            capsule.bounds.origin = capsule.bounds.origin.offset(by: vector)
            return .capsule(capsule)

        case .polyline(var polyline):
            polyline.points = polyline.points.map { $0.offset(by: vector) }
            return .polyline(polyline)

        case .symmetricPath(var path):
            path.points = path.points.map { $0.offset(by: vector) }
            // The mirror axis travels with the geometry, otherwise moving a
            // symmetric path sideways would silently reshape it.
            switch path.axis {
            case .vertical: path.axisPosition += vector.dx
            case .horizontal: path.axisPosition += vector.dy
            }
            return .symmetricPath(path)

        case .compound, .importedPath:
            // Compounds move by moving their children; imported paths carry raw
            // path data with no semantic geometry to translate.
            return self
        }
    }
}
