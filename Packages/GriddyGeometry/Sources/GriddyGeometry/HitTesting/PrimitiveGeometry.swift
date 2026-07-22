//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// Distance and bounds queries against a primitive's centerline.
///
/// These operate on the *centerline*, not the outlined shape. Outlining happens
/// later in the pipeline and is a separate concern. See spec 10.5.
public enum PrimitiveGeometry {

    // MARK: Distance

    /// The shortest distance from a point to a primitive's centerline.
    ///
    /// Returns `nil` for primitives whose geometry cannot be resolved locally:
    /// compounds reference other primitives by identity, and imported paths
    /// carry raw path data rather than semantic geometry.
    public static func distance(from point: IconPoint,
                                to primitive: IconPrimitive) -> Double? {
        switch primitive {
        case .line(let line):
            distance(from: point, toSegmentFrom: line.start, to: line.end)

        case .circle(let circle):
            abs(point.distance(to: circle.center) - circle.radius)

        case .arc(let arc):
            distance(from: point, to: arc)

        case .roundedRect(let rect):
            abs(signedDistance(from: point,
                               toRoundedRect: rect.bounds,
                               cornerRadius: rect.effectiveCornerRadius))

        case .capsule(let capsule):
            abs(signedDistance(from: point,
                               toRoundedRect: capsule.bounds,
                               cornerRadius: capsule.cornerRadius))

        case .polyline(let polyline):
            distance(from: point,
                     toPoints: polyline.points,
                     isClosed: polyline.isClosed)

        case .symmetricPath(let path):
            distance(from: point,
                     toPoints: path.points + path.mirroredPoints,
                     isClosed: true)

        case .compound, .importedPath:
            nil
        }
    }

    private static func distance(from point: IconPoint, to arc: ArcPrimitive) -> Double {
        let toPoint = arc.center.vector(to: point)

        // A point exactly at the centre has no defined angle; the whole arc is
        // then equidistant, so any point on it will do.
        guard toPoint.length > .ulpOfOne else {
            return arc.radius
        }

        let angle = IconAngle(radians: atan2(toPoint.dy, toPoint.dx))
        if arc.contains(angle: angle) {
            return abs(toPoint.length - arc.radius)
        }
        return min(point.distance(to: arc.startPoint),
                   point.distance(to: arc.endPoint))
    }

    /// Distance from a point to a line segment.
    public static func distance(from point: IconPoint,
                                toSegmentFrom start: IconPoint,
                                to end: IconPoint) -> Double {
        let segment = start.vector(to: end)
        let lengthSquared = segment.dot(segment)

        guard lengthSquared > .ulpOfOne else {
            return point.distance(to: start)
        }

        let t = min(1, max(0, start.vector(to: point).dot(segment) / lengthSquared))
        let projection = start.offset(by: segment.scaled(by: t))
        return point.distance(to: projection)
    }

    private static func distance(from point: IconPoint,
                                 toPoints points: [IconPoint],
                                 isClosed: Bool) -> Double {
        guard let first = points.first else {
            return .infinity
        }
        guard points.count > 1 else {
            return point.distance(to: first)
        }

        var shortest = Double.infinity
        for index in 0..<(points.count - 1) {
            shortest = min(shortest, distance(from: point,
                                              toSegmentFrom: points[index],
                                              to: points[index + 1]))
        }
        if isClosed, let last = points.last {
            shortest = min(shortest, distance(from: point,
                                              toSegmentFrom: last,
                                              to: first))
        }
        return shortest
    }

    /// Signed distance to a rounded rectangle's outline.
    ///
    /// Negative inside, positive outside. This is the standard rounded-box
    /// signed distance function.
    public static func signedDistance(from point: IconPoint,
                                      toRoundedRect rect: IconRect,
                                      cornerRadius: Double) -> Double {
        let center = rect.center
        let half = IconVector(dx: rect.size.width / 2, dy: rect.size.height / 2)
        let radius = max(0, min(cornerRadius, min(half.dx, half.dy)))

        // Fold into one quadrant; the shape is symmetric about both axes.
        let offset = IconVector(dx: abs(point.x - center.x),
                                dy: abs(point.y - center.y))
        let corner = IconVector(dx: offset.dx - (half.dx - radius),
                                dy: offset.dy - (half.dy - radius))

        let outside = IconVector(dx: max(corner.dx, 0), dy: max(corner.dy, 0))
        let inside = min(max(corner.dx, corner.dy), 0)
        return outside.length + inside - radius
    }

    // MARK: Bounds

    /// The bounding box of a primitive's centerline.
    public static func bounds(of primitive: IconPrimitive) -> IconRect? {
        switch primitive {
        case .line(let line):
            bounds(containing: [line.start, line.end])

        case .circle(let circle):
            circle.bounds

        case .arc(let arc):
            bounds(of: arc)

        case .roundedRect(let rect):
            rect.bounds

        case .capsule(let capsule):
            capsule.bounds

        case .polyline(let polyline):
            bounds(containing: polyline.points)

        case .symmetricPath(let path):
            bounds(containing: path.points + path.mirroredPoints)

        case .compound, .importedPath:
            nil
        }
    }

    private static func bounds(of arc: ArcPrimitive) -> IconRect {
        // The extremes of an arc are its endpoints plus any cardinal direction
        // the sweep passes through. Using only the endpoints would understate
        // the bounds of any arc crossing an axis.
        var points = [arc.startPoint, arc.endPoint]

        for quarter in 0..<4 {
            let angle = IconAngle(radians: Double(quarter) * .pi / 2)
            if arc.contains(angle: angle) {
                points.append(arc.point(atAngle: angle))
            }
        }

        return bounds(containing: points) ?? IconRect(origin: arc.center, size: .zero)
    }

    /// The smallest rectangle containing every point.
    public static func bounds(containing points: [IconPoint]) -> IconRect? {
        guard let first = points.first else {
            return nil
        }

        var minX = first.x, maxX = first.x
        var minY = first.y, maxY = first.y

        for point in points.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }

        return IconRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
