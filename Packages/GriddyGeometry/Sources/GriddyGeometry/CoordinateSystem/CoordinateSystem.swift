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
/// Cap height is the right anchor because it is what a symbol aligns against in
/// text, and because it is stable: it measures identically at Small, Medium and
/// Large in the templates examined. See spec 9.1.
///
/// **Three regions, deliberately distinct.** An earlier version of this type had
/// a single `canvasBounds` doing all three jobs, which was wrong in both
/// directions: it implied artwork should fit inside cap height, and it defaulted
/// the width to 16 units when real symbols are 27 to 34 units wide.
///
/// - ``capHeightBox`` is a *reference*, not a boundary. Artwork routinely
///   exceeds it — measured at 20.5 and 27.3 units tall in two real templates,
///   extending both below the baseline and above the capline.
/// - ``marginBox`` is a *real bound*, horizontally. Apple's own artwork stays
///   inside it in every template examined.
/// - ``designArea`` is the drawing surface. Nothing in the template bounds
///   artwork vertically, so this is a generous default rather than a rule.
public struct CoordinateSystem: Codable, Hashable, Sendable {

    /// The number of units spanning baseline to capline. Fixed by the spec.
    public static let unitsPerCapHeight: Double = 16

    /// How far the design area reaches below the baseline and above the
    /// capline, in units.
    ///
    /// Eight units is half a cap height at each end, comfortably clearing the
    /// 6.4 below and 4.9 above measured in real templates.
    public static let designAreaOvershoot: Double = 8

    /// Width used when a template carries no usable margin guides.
    public static let fallbackWidthInUnits: Double = 16

    /// The metrics this system was derived from, retained so the export
    /// transform can be reconstructed without re-reading the template.
    public let templateMetrics: TemplateMetrics

    public init(templateMetrics: TemplateMetrics) {
        self.templateMetrics = templateMetrics
    }

    /// The size of one unit, expressed in template coordinates.
    public var unitInTemplateSpace: Double {
        templateMetrics.capHeight / Self.unitsPerCapHeight
    }

    // MARK: Regions

    /// The symbol's width, from left margin to right margin, in units.
    public var widthInUnits: Double {
        let unit = unitInTemplateSpace
        guard unit > .ulpOfOne else {
            return Self.fallbackWidthInUnits
        }
        let width = templateMetrics.marginWidth / unit
        return width > .ulpOfOne ? width : Self.fallbackWidthInUnits
    }

    /// Baseline to capline: what a symbol aligns against in text.
    ///
    /// A guide, drawn like the baseline itself. Artwork is expected to exceed
    /// it and doing so is not an error.
    public var capHeightBox: IconRect {
        IconRect(x: 0, y: 0, width: widthInUnits, height: Self.unitsPerCapHeight)
    }

    /// The horizontal bound on artwork, taken from the template's margins.
    ///
    /// This is the one extent the template genuinely constrains. It spans the
    /// full design area vertically because the constraint is horizontal only.
    public var marginBox: IconRect {
        IconRect(x: 0,
                 y: designArea.minY,
                 width: widthInUnits,
                 height: designArea.size.height)
    }

    /// The drawing surface.
    public var designArea: IconRect {
        IconRect(x: 0,
                 y: -Self.designAreaOvershoot,
                 width: widthInUnits,
                 height: Self.unitsPerCapHeight + Self.designAreaOvershoot * 2)
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
