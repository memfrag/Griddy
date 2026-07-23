//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

/// The drawing grid.
///
/// `canvasSize` is populated from the template on import and is not
/// user-authored. The remaining fields are user-configurable. See spec 9.2.
public struct GridDefinition: Codable, Hashable, Sendable {

    public var canvasSize: IconSize
    public var primaryInterval: Double
    public var secondaryDivisions: Int
    public var visibleGuides: GuideSet
    public var snapTolerance: Double

    public init(canvasSize: IconSize,
                primaryInterval: Double = 1.0,
                secondaryDivisions: Int = 4,
                visibleGuides: GuideSet = .default,
                snapTolerance: Double = 0.125) {
        self.canvasSize = canvasSize
        self.primaryInterval = primaryInterval
        self.secondaryDivisions = secondaryDivisions
        self.visibleGuides = visibleGuides
        self.snapTolerance = snapTolerance
    }

    public var showsPrimaryGrid: Bool {
        get { visibleGuides.contains(.primaryGrid) }
        set { visibleGuides.set(.primaryGrid, to: newValue) }
    }

    public var showsSecondaryGrid: Bool {
        get { visibleGuides.contains(.secondaryGrid) }
        set { visibleGuides.set(.secondaryGrid, to: newValue) }
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case canvasSize, primaryInterval, secondaryDivisions
        case visibleGuides, snapTolerance
        case showsPrimaryGrid, showsSecondaryGrid
    }

    /// Decodes documents written before guides became a set.
    ///
    /// Those files carry `showsPrimaryGrid` and `showsSecondaryGrid` and know
    /// nothing of the other guides, which take their default visibility. A
    /// `safeArea` key from an even older document is simply ignored: the guide
    /// it described has been removed.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        canvasSize = try container.decode(IconSize.self, forKey: .canvasSize)
        primaryInterval = try container.decode(Double.self, forKey: .primaryInterval)
        secondaryDivisions = try container.decode(Int.self, forKey: .secondaryDivisions)
        snapTolerance = try container.decode(Double.self, forKey: .snapTolerance)

        if let guides = try container.decodeIfPresent(
            GuideSet.self, forKey: .visibleGuides) {
            visibleGuides = guides
        } else {
            visibleGuides = .default
            if let shows = try container.decodeIfPresent(
                Bool.self, forKey: .showsPrimaryGrid) {
                visibleGuides.set(.primaryGrid, to: shows)
            }
            if let shows = try container.decodeIfPresent(
                Bool.self, forKey: .showsSecondaryGrid) {
                visibleGuides.set(.secondaryGrid, to: shows)
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(canvasSize, forKey: .canvasSize)
        try container.encode(primaryInterval, forKey: .primaryInterval)
        try container.encode(secondaryDivisions, forKey: .secondaryDivisions)
        try container.encode(visibleGuides, forKey: .visibleGuides)
        try container.encode(snapTolerance, forKey: .snapTolerance)
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
        GridDefinition(canvasSize: coordinateSystem.designArea.size)
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
