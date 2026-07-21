//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// A size in Griddy's icon coordinate space, expressed in units.
public struct IconSize: Codable, Hashable, Sendable {

    public var width: Double
    public var height: Double

    public static let zero = IconSize(width: 0, height: 0)

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}
