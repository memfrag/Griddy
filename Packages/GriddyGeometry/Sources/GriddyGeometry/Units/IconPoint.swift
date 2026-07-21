//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// A point in Griddy's icon coordinate space.
///
/// Coordinates are expressed in units, where one unit is a sixteenth of the
/// template's cap height. Y increases upward. See spec 9.1.
public struct IconPoint: Codable, Hashable, Sendable {

    public var x: Double
    public var y: Double

    public static let zero = IconPoint(x: 0, y: 0)

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public func offset(by vector: IconVector) -> IconPoint {
        IconPoint(x: x + vector.dx, y: y + vector.dy)
    }

    public func vector(to other: IconPoint) -> IconVector {
        IconVector(dx: other.x - x, dy: other.y - y)
    }

    public func distance(to other: IconPoint) -> Double {
        vector(to: other).length
    }
}
