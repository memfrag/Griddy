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
/// - ``marginBox`` spans the symbol's advance width: from the glyph origin to
///   where the next glyph would start. It is *not* a bound on artwork. It is
///   the horizontal room the symbol claims in a line of text, an output of the
///   design rather than a constraint on it. See ``GlyphMetrics``.
/// - ``designArea`` is the drawing surface, and is deliberately larger than
///   both, in both directions.
///
/// **The design area used to be exactly the margin box wide**, which was wrong
/// twice over. It made an advance width inherited from whichever template the
/// document started from into a wall the artwork could not cross — so every new
/// document was 26.6 units wide because that is how wide `custom.cup.and.bag`
/// happened to be. Margins now sit *inside* the canvas, where a guide belongs.
public struct CoordinateSystem: Codable, Hashable, Sendable {

    /// The number of units spanning baseline to capline. Fixed by the spec.
    public static let unitsPerCapHeight: Double = 16

    /// How far the design area reaches below the baseline and above the
    /// capline, in units.
    ///
    /// Eight units is half a cap height at each end, comfortably clearing the
    /// 6.4 below and 4.9 above measured in real templates.
    public static let designAreaOvershoot: Double = 8

    /// How far the design area reaches to either side of the drawing width.
    ///
    /// Artwork may legitimately sit outside its own advance — a glyph can
    /// overhang its side bearings — and the designer needs somewhere to put it
    /// while deciding. Matches the vertical overshoot.
    public static let designAreaSideOvershoot: Double = 8

    /// The nominal drawing width, in units: two cap heights.
    ///
    /// A round number on purpose. The design area used to be the template's
    /// advance width plus overshoot, which made a new document 42.6 units wide
    /// — 26.63 of advance inherited from `custom.cup.and.bag`, plus 16. The
    /// fraction meant nothing, and neither did the 26.63: it described how wide
    /// a bag next to a cup happens to be.
    ///
    /// Two cap heights comfortably holds the widest advance measured in real
    /// templates (28.5 units, `takeoutbag.and.cup.and.straw` at Black), and the
    /// overshoot leaves room on either side of it.
    public static let designAreaWidthInUnits: Double = 32

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

    /// The symbol's advance width, from left margin to right margin, in units.
    ///
    /// The template's value, which is the starting point for an imported
    /// symbol. Export recomputes it from the artwork unless the document
    /// overrides it.
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

    /// The symbol's advance: origin to next origin, spanning the design area
    /// vertically because it says nothing about vertical extent.
    ///
    /// A guide, not a bound. Artwork inside it is the usual case, not a rule.
    public var marginBox: IconRect {
        IconRect(x: 0,
                 y: designArea.minY,
                 width: widthInUnits,
                 height: designArea.size.height)
    }

    /// The drawing surface: a fixed 48 × 32 units, in whole units throughout.
    ///
    /// Independent of the template. The canvas is where you draw, not a
    /// statement about how wide the symbol is — that is ``marginBox``, which is
    /// computed from the artwork and drawn inside this.
    public var designArea: IconRect {
        IconRect(x: -Self.designAreaSideOvershoot,
                 y: -Self.designAreaOvershoot,
                 width: Self.designAreaWidthInUnits + Self.designAreaSideOvershoot * 2,
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
