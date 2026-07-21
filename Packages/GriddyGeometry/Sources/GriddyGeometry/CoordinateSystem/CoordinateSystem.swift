//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// Griddy's icon coordinate system, derived entirely from a template.
///
/// The whole system hangs off a single anchor:
///
///     1 unit = capHeight / 16
///
/// From that: canvas height is fixed at 16u spanning baseline to capline,
/// canvas width is free, the origin sits at the baseline and left margin, and
/// Y increases upward. See spec 9.1.
///
/// This type is never authored directly. It is produced by
/// ``init(templateMetrics:canvasWidthInUnits:)`` during import.
public struct CoordinateSystem: Codable, Hashable, Sendable {

    /// The number of units spanning baseline to capline. Fixed by the spec.
    public static let unitsPerCapHeight: Double = 16

    /// The metrics this system was derived from, retained so the export
    /// transform can be reconstructed without re-reading the template.
    public let templateMetrics: TemplateMetrics

    /// The canvas width in units. Height is always ``unitsPerCapHeight``.
    public var canvasWidthInUnits: Double

    public init(templateMetrics: TemplateMetrics,
                canvasWidthInUnits: Double = CoordinateSystem.unitsPerCapHeight) {
        self.templateMetrics = templateMetrics
        self.canvasWidthInUnits = canvasWidthInUnits
    }

    /// The size of one unit, expressed in template coordinates.
    public var unitInTemplateSpace: Double {
        templateMetrics.capHeight / Self.unitsPerCapHeight
    }

    /// The canvas bounds in unit space, with the origin at baseline/left margin.
    public var canvasBounds: IconRect {
        IconRect(x: 0,
                 y: 0,
                 width: canvasWidthInUnits,
                 height: Self.unitsPerCapHeight)
    }

    // MARK: Transforms

    /// Converts a point from unit space into template (SVG) space.
    ///
    /// This is the export transform: a uniform scale, a Y flip, and a
    /// translation to the template origin. No shear or non-uniform scaling is
    /// ever applied. See spec 9.1.
    public func templatePoint(from point: IconPoint) -> IconPoint {
        let unit = unitInTemplateSpace
        return IconPoint(x: templateMetrics.leftMarginX + point.x * unit,
                         y: templateMetrics.baselineY - point.y * unit)
    }

    /// Converts a point from template (SVG) space into unit space.
    public func iconPoint(from point: IconPoint) -> IconPoint {
        let unit = unitInTemplateSpace
        guard unit > .ulpOfOne else {
            return .zero
        }
        return IconPoint(x: (point.x - templateMetrics.leftMarginX) / unit,
                         y: (templateMetrics.baselineY - point.y) / unit)
    }

    /// Converts a length from unit space into template space.
    public func templateLength(from length: Double) -> Double {
        length * unitInTemplateSpace
    }
}
