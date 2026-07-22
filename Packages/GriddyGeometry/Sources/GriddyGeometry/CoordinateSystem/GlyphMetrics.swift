//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// A symbol's horizontal metrics: where it sits relative to its origin, and how
/// much room it claims in a line of text.
///
/// **SF Symbols are glyphs in a font**, which is stated outright in the header
/// comment of any template the SF Symbols app writes:
///
///     glyph: "102240", point size: 100.0, font version: "21.1d1e1"
///
/// Everything about the template's geometry follows from that, and the split
/// between what varies and what does not is exactly a font's:
///
/// - **Baseline and cap height are font-wide.** Every glyph in a typeface
///   shares them, which is why they measure identically in every template and
///   for every symbol -- 696 and 625.541 at Small in all three files examined.
///   No symbol can move them, and Griddy derives its unit from cap height for
///   precisely this reason (``CoordinateSystem``).
/// - **The margins are per-glyph.** They are the left side bearing and the
///   advance width. They differ between symbols because glyphs are different
///   widths, and between weights because each weight is a separate font in
///   which the same glyph is drawn heavier, and therefore wider.
///
/// The template encodes the glyph origin directly: a slot group's transform is
/// `(left margin, baseline)`. Measured across three templates and three weights
/// each, `groupX - leftMarginX` is 0.00 in all nine. Path data is therefore
/// expressed relative to the left margin and the baseline -- the pen position.
public struct GlyphMetrics: Codable, Hashable, Sendable {

    /// The gap between the glyph origin and the artwork's leftmost point.
    public var leftSideBearing: Double

    /// The gap between the artwork's rightmost point and the next glyph's
    /// origin.
    public var rightSideBearing: Double

    public init(leftSideBearing: Double, rightSideBearing: Double) {
        self.leftSideBearing = leftSideBearing
        self.rightSideBearing = rightSideBearing
    }

    /// The side bearing Apple's own symbols use, in template units at the
    /// templates' point size of 100.
    ///
    /// Measured as exactly 9.765625 on the left of all nine masters across
    /// `app`, `apple.terminal` and `takeoutbag.and.cup.and.straw`, and on the
    /// right of the first two. The value is `10000 / 1024`: 100 font units in a
    /// 1024-unit em at point size 100.
    ///
    /// `takeoutbag` is the exception, with right bearings of 6.67, 4.09 and
    /// 2.36 across the three weights. That is a deliberate optical adjustment,
    /// which the template's own notes describe: *"Leading and trailing margins
    /// … can be adjusted by modifying the x-location of the margin guidelines.
    /// Modifications are automatically applied proportionally to all scales and
    /// weights."* Hence ``standard`` is a default, not a rule, and
    /// ``SymbolDocument`` allows per-weight overrides.
    public static let standardSideBearingInTemplateUnits: Double = 10000 / 1024

    /// The default metrics, in units, for a given unit size.
    public static func standard(unitInTemplateSpace unit: Double) -> GlyphMetrics {
        guard unit > .ulpOfOne else {
            return GlyphMetrics(leftSideBearing: 0, rightSideBearing: 0)
        }
        let bearing = standardSideBearingInTemplateUnits / unit
        return GlyphMetrics(leftSideBearing: bearing, rightSideBearing: bearing)
    }

    /// The advance width for artwork of the given extent.
    public func advance(forArtworkWidth width: Double) -> Double {
        leftSideBearing + width + rightSideBearing
    }
}

public extension CoordinateSystem {

    /// The standard side bearing in units.
    var standardSideBearing: Double {
        GlyphMetrics.standard(unitInTemplateSpace: unitInTemplateSpace).leftSideBearing
    }

    /// Where a master's glyph origin must sit, in the unit space the artwork was
    /// drawn in, for its left side bearing to come out as asked.
    ///
    /// Griddy's x = 0 is the left margin, so artwork drawn at x = 2.2u already
    /// has roughly the standard bearing. Artwork drawn anywhere else does not,
    /// and the bearing would then vary from master to master -- which reads, in
    /// the SF Symbols app, as the symbol sliding sideways as the weight
    /// changes. Export normalises by shifting each master to the bearing it is
    /// supposed to have.
    func originX(forArtworkMinX minX: Double, leftSideBearing: Double) -> Double {
        minX - leftSideBearing
    }
}
