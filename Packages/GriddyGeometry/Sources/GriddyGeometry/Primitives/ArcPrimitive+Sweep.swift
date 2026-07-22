//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

extension ArcPrimitive {

    /// The angular extent of the arc, always positive, in radians.
    public var sweep: Double {
        let turn = 2 * Double.pi
        let raw = isClockwise
            ? startAngle.radians - endAngle.radians
            : endAngle.radians - startAngle.radians

        var value = raw.truncatingRemainder(dividingBy: turn)
        if value < 0 {
            value += turn
        }
        // A start and end that coincide describe a full circle, not an empty
        // arc. Anything else would make a 360 degree arc invisible.
        return value == 0 ? turn : value
    }

    /// Whether an angle lies within the arc's swept range.
    public func contains(angle: IconAngle) -> Bool {
        let turn = 2 * Double.pi
        let offset = isClockwise
            ? startAngle.radians - angle.radians
            : angle.radians - startAngle.radians

        var normalized = offset.truncatingRemainder(dividingBy: turn)
        if normalized < 0 {
            normalized += turn
        }
        return normalized <= sweep + .ulpOfOne
    }

    /// The angle on the arc closest to an arbitrary angle.
    ///
    /// Returns the angle itself when it lies on the arc, otherwise whichever
    /// endpoint is angularly nearer.
    public func nearestAngle(to angle: IconAngle) -> IconAngle {
        if contains(angle: angle) {
            return angle
        }

        let turn = 2 * Double.pi

        func angularDistance(_ a: Double, _ b: Double) -> Double {
            var delta = abs(a - b).truncatingRemainder(dividingBy: turn)
            if delta > turn / 2 {
                delta = turn - delta
            }
            return delta
        }

        let toStart = angularDistance(angle.radians, startAngle.radians)
        let toEnd = angularDistance(angle.radians, endAngle.radians)
        return toStart <= toEnd ? startAngle : endAngle
    }
}
