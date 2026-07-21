//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// An axis-aligned rectangle in Griddy's icon coordinate space.
///
/// The origin is the corner with the smallest x and y. Because Y increases
/// upward, that is the *bottom* left corner. See spec 9.1.
public struct IconRect: Codable, Hashable, Sendable {

    public var origin: IconPoint
    public var size: IconSize

    public static let zero = IconRect(origin: .zero, size: .zero)

    public init(origin: IconPoint, size: IconSize) {
        self.origin = origin
        self.size = size
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(origin: IconPoint(x: x, y: y),
                  size: IconSize(width: width, height: height))
    }

    public var minX: Double { origin.x }
    public var minY: Double { origin.y }
    public var maxX: Double { origin.x + size.width }
    public var maxY: Double { origin.y + size.height }
    public var midX: Double { origin.x + size.width / 2 }
    public var midY: Double { origin.y + size.height / 2 }

    public var center: IconPoint {
        IconPoint(x: midX, y: midY)
    }

    public func contains(_ point: IconPoint) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }

    /// The rectangle inset on every edge by `amount`.
    ///
    /// A negative amount outsets. The result is clamped to zero extent rather
    /// than being allowed to invert.
    public func inset(by amount: Double) -> IconRect {
        let width = max(0, size.width - amount * 2)
        let height = max(0, size.height - amount * 2)
        return IconRect(x: minX + amount,
                        y: minY + amount,
                        width: width,
                        height: height)
    }
}
