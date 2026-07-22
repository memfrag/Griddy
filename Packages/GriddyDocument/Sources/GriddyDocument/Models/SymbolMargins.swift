//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

/// The symbol's horizontal metrics, per weight.
///
/// Margins are an *output* of the design: how much room the symbol claims in a
/// line of text, given how wide the artwork turned out. Export computes them
/// from each master's own outline, which is why they are per-weight — a heavier
/// master is a wider glyph and claims more room.
///
/// Griddy used to treat them as an input, inheriting whatever the source
/// template happened to carry and never writing them back, so an exported
/// symbol claimed the advance width of an unrelated symbol. See spec 9.5.
///
/// Overrides exist because Apple's own symbols use them: `takeoutbag.and.cup.
/// and.straw` has right side bearings of 6.67, 4.09 and 2.36 where the default
/// is 9.77, an optical adjustment for a shape whose right edge is a round cup.
public struct SymbolMargins: Codable, Hashable, Sendable {

    /// Per-weight bearings, in units. A weight absent here is computed.
    public var overrides: [SymbolWeight: GlyphMetrics]

    public init(overrides: [SymbolWeight: GlyphMetrics] = [:]) {
        self.overrides = overrides
    }

    /// Whether every weight takes its bearings from the artwork.
    public var isAutomatic: Bool {
        overrides.isEmpty
    }

    /// The bearings to use for a weight: the override, or the standard.
    public func metrics(for weight: SymbolWeight,
                        in coordinateSystem: CoordinateSystem) -> GlyphMetrics {
        overrides[weight]
            ?? GlyphMetrics.standard(
                unitInTemplateSpace: coordinateSystem.unitInTemplateSpace)
    }

    public mutating func override(_ metrics: GlyphMetrics,
                                  for weight: SymbolWeight) {
        overrides[weight] = metrics
    }

    public mutating func clearOverride(for weight: SymbolWeight) {
        overrides.removeValue(forKey: weight)
    }
}

/// What a single master's metrics work out to.
public struct ResolvedMargins: Hashable, Sendable {

    /// Where the glyph origin sits in the unit space the artwork was drawn in.
    ///
    /// Artwork is shifted by this on export so the left side bearing comes out
    /// as intended rather than depending on where the designer happened to
    /// draw. Without it the bearing varies per master, and the symbol appears
    /// to slide sideways as the weight changes.
    public var originX: Double

    /// Origin to next origin, in units.
    public var advance: Double

    public var metrics: GlyphMetrics

    public init(originX: Double, advance: Double, metrics: GlyphMetrics) {
        self.originX = originX
        self.advance = advance
        self.metrics = metrics
    }

    /// The advance a document claims before anything has been drawn.
    ///
    /// One cap height, so an empty canvas shows a square-ish symbol's worth of
    /// room. Measuring the empty outline instead would give just the two side
    /// bearings -- about 4.4 units -- which reads as two guides huddled at the
    /// left edge rather than as a starting point.
    public static let emptyAdvanceInUnits: Double = 16

    /// Resolves one master against its outline.
    ///
    /// With nothing drawn there is nothing to measure, so the guides take
    /// ``emptyAdvanceInUnits`` and adapt as soon as the first primitive lands.
    public static func resolve(outline: OutlinePath,
                               weight: SymbolWeight,
                               margins: SymbolMargins,
                               coordinateSystem: CoordinateSystem)
    -> ResolvedMargins {
        let metrics = margins.metrics(for: weight, in: coordinateSystem)

        // Centred in the design area rather than sitting at the origin. The
        // canvas is deliberately asymmetric about x = 0 -- that is the glyph
        // origin, and glyphs grow rightward from it -- so an advance placed at
        // the origin lands at 17% to 50% of the width and reads as misaligned.
        // Once anything is drawn the guides follow the artwork instead.
        guard let bounds = outline.bounds else {
            let advance = Self.emptyAdvanceInUnits
            return ResolvedMargins(
                originX: coordinateSystem.designArea.center.x - advance / 2,
                advance: advance,
                metrics: metrics)
        }

        return ResolvedMargins(
            originX: bounds.minX - metrics.leftSideBearing,
            advance: metrics.advance(forArtworkWidth: bounds.size.width),
            metrics: metrics)
    }
}
