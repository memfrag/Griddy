//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

/// The document facts a constraint needs in order to be resolved.
///
/// Passed in rather than reached for, so this package depends only on
/// `GriddyGeometry`. Key shapes and the grid live in the document layer, which
/// depends on this one; the dependency runs one way. See spec 16.2.
public struct ConstraintContext: Sendable {

    /// The cap-height reference box, which is what centring centres on.
    public var capHeightBox: IconRect

    /// Key shape bounds by identifier, for on-key-shape constraints.
    public var keyShapeBounds: [UUID: IconRect]

    /// Spacing of the finest grid, for on-grid constraints.
    public var gridInterval: Double

    public init(capHeightBox: IconRect,
                keyShapeBounds: [UUID: IconRect] = [:],
                gridInterval: Double = 0.25) {
        self.capHeightBox = capHeightBox
        self.keyShapeBounds = keyShapeBounds
        self.gridInterval = gridInterval
    }
}
