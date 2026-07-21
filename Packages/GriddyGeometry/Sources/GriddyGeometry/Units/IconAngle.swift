//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// An angle, stored in radians and presented in degrees.
///
/// The inspector works in degrees (spec 8.6) while the geometry works in
/// radians. Storing one canonical representation avoids drift between them.
public struct IconAngle: Codable, Hashable, Sendable {

    public var radians: Double

    public static let zero = IconAngle(radians: 0)

    public init(radians: Double) {
        self.radians = radians
    }

    public init(degrees: Double) {
        self.radians = degrees * .pi / 180
    }

    public var degrees: Double {
        radians * 180 / .pi
    }

    /// The angle wrapped into `0..<2pi`.
    public var normalized: IconAngle {
        let turn = 2 * Double.pi
        var value = radians.truncatingRemainder(dividingBy: turn)
        if value < 0 {
            value += turn
        }
        return IconAngle(radians: value)
    }

    /// The unit vector pointing along this angle, measured counterclockwise
    /// from the positive X axis.
    public var direction: IconVector {
        IconVector(dx: cos(radians), dy: sin(radians))
    }
}
