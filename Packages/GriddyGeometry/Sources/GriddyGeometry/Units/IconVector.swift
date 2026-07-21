//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// A displacement in Griddy's icon coordinate space, expressed in units.
public struct IconVector: Codable, Hashable, Sendable {

    public var dx: Double
    public var dy: Double

    public static let zero = IconVector(dx: 0, dy: 0)

    public init(dx: Double, dy: Double) {
        self.dx = dx
        self.dy = dy
    }

    public var length: Double {
        (dx * dx + dy * dy).squareRoot()
    }

    /// The vector scaled to unit length, or `nil` if the vector is degenerate.
    public var normalized: IconVector? {
        let length = self.length
        guard length > .ulpOfOne else {
            return nil
        }
        return IconVector(dx: dx / length, dy: dy / length)
    }

    /// The vector rotated a quarter turn counterclockwise.
    ///
    /// Used to build stroke offsets when outlining. See spec 10.5.
    public var perpendicular: IconVector {
        IconVector(dx: -dy, dy: dx)
    }

    public func scaled(by factor: Double) -> IconVector {
        IconVector(dx: dx * factor, dy: dy * factor)
    }

    public func dot(_ other: IconVector) -> Double {
        dx * other.dx + dy * other.dy
    }

    /// The Z component of the 3D cross product, positive when `other` lies
    /// counterclockwise of the receiver.
    public func cross(_ other: IconVector) -> Double {
        dx * other.dy - dy * other.dx
    }
}
