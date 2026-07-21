//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

/// The drawing grid.
///
/// `canvasSize` and `safeArea` are populated from the template on import and
/// are not user-authored. The remaining fields are user-configurable. See
/// spec 9.2.
public struct GridDefinition: Codable, Hashable, Sendable {

    public var canvasSize: IconSize
    public var safeArea: IconRect
    public var primaryInterval: Double
    public var secondaryDivisions: Int
    public var showsPrimaryGrid: Bool
    public var showsSecondaryGrid: Bool
    public var snapTolerance: Double

    public init(canvasSize: IconSize,
                safeArea: IconRect,
                primaryInterval: Double = 1.0,
                secondaryDivisions: Int = 4,
                showsPrimaryGrid: Bool = true,
                showsSecondaryGrid: Bool = true,
                snapTolerance: Double = 0.125) {
        self.canvasSize = canvasSize
        self.safeArea = safeArea
        self.primaryInterval = primaryInterval
        self.secondaryDivisions = secondaryDivisions
        self.showsPrimaryGrid = showsPrimaryGrid
        self.showsSecondaryGrid = showsSecondaryGrid
        self.snapTolerance = snapTolerance
    }

    /// The spacing of the secondary grid, in units.
    ///
    /// Returns the primary interval when subdivision is disabled, so callers
    /// never divide by zero.
    public var secondaryInterval: Double {
        guard secondaryDivisions > 0 else {
            return primaryInterval
        }
        return primaryInterval / Double(secondaryDivisions)
    }

    /// The default grid for a coordinate system, per spec 9.2.
    public static func `default`(for coordinateSystem: CoordinateSystem) -> GridDefinition {
        let bounds = coordinateSystem.canvasBounds
        return GridDefinition(canvasSize: bounds.size,
                              safeArea: bounds.inset(by: 1))
    }

    /// Snaps a value to the nearest secondary grid line when it lies within
    /// the snap tolerance, otherwise leaves it alone.
    public func snapped(_ value: Double) -> Double {
        let interval = secondaryInterval
        guard interval > .ulpOfOne else {
            return value
        }
        let nearest = (value / interval).rounded() * interval
        return abs(nearest - value) <= snapTolerance ? nearest : value
    }

    public func snapped(_ point: IconPoint) -> IconPoint {
        IconPoint(x: snapped(point.x), y: snapped(point.y))
    }
}
