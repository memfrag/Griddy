//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// Picking primitives from a canvas location.
public enum HitTesting {

    /// Whether a point is within `tolerance` of a primitive's centerline.
    public static func hit(_ primitive: IconPrimitive,
                           at point: IconPoint,
                           tolerance: Double) -> Bool {
        guard let distance = PrimitiveGeometry.distance(from: point, to: primitive) else {
            // No semantic geometry to measure against. Fall back to the bounding
            // box so imported artwork is still selectable.
            guard let bounds = PrimitiveGeometry.bounds(of: primitive) else {
                return false
            }
            return bounds.inset(by: -tolerance).contains(point)
        }
        return distance <= tolerance
    }

    /// The topmost primitive at a point.
    ///
    /// `primitives` is expected in draw order, back to front, so the last match
    /// is the one the user sees on top and therefore the one they mean.
    public static func topmost(in primitives: [IconPrimitive],
                               at point: IconPoint,
                               tolerance: Double) -> IconPrimitive? {
        primitives.last { primitive in
            primitive.attributes.isVisible
                && hit(primitive, at: point, tolerance: tolerance)
        }
    }

    /// Every primitive whose bounds intersect a rectangle, for marquee
    /// selection.
    public static func primitives(in primitives: [IconPrimitive],
                                  intersecting rect: IconRect) -> [IconPrimitive] {
        primitives.filter { primitive in
            guard primitive.attributes.isVisible,
                  let bounds = PrimitiveGeometry.bounds(of: primitive) else {
                return false
            }
            return bounds.intersects(rect)
        }
    }
}

extension IconRect {

    /// Whether two rectangles overlap, touching edges included.
    public func intersects(_ other: IconRect) -> Bool {
        minX <= other.maxX && maxX >= other.minX
            && minY <= other.maxY && maxY >= other.minY
    }
}
