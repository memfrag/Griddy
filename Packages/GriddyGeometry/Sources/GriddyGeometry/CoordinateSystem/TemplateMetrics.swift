//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// The typographic metrics extracted from an SF Symbols template, expressed in
/// the template's own SVG coordinate space.
///
/// This is the raw material the coordinate system is derived from. Griddy never
/// authors these values; they are read from the template on import, including
/// the bundled blank template used when creating a new document. See spec 7.1
/// and 14.2.
///
/// Note that SVG's Y axis increases downward, so `caplineY` is numerically
/// *smaller* than `baselineY`.
public struct TemplateMetrics: Codable, Hashable, Sendable {

    /// The Y coordinate of the baseline guide, in template space.
    public var baselineY: Double

    /// The Y coordinate of the capline guide, in template space.
    public var caplineY: Double

    /// The left edge of the artwork margin, in template space.
    public var leftMarginX: Double

    /// The right edge of the artwork margin, in template space.
    ///
    /// Together with ``leftMarginX`` this is the symbol's advance width, and it
    /// is a real bound: artwork stays inside it in Apple's own templates.
    /// Nothing in the template bounds artwork vertically.
    public var rightMarginX: Double

    /// The alignment rectangle for each scale, in template space.
    public var alignmentRects: [SymbolScale: TemplateRect]

    public init(baselineY: Double,
                caplineY: Double,
                leftMarginX: Double,
                rightMarginX: Double,
                alignmentRects: [SymbolScale: TemplateRect]) {
        self.baselineY = baselineY
        self.caplineY = caplineY
        self.leftMarginX = leftMarginX
        self.rightMarginX = rightMarginX
        self.alignmentRects = alignmentRects
    }

    /// The distance between the margins, in template space.
    public var marginWidth: Double {
        abs(rightMarginX - leftMarginX)
    }

    /// The distance between baseline and capline, in template space.
    ///
    /// Always positive, regardless of SVG's downward Y axis.
    public var capHeight: Double {
        abs(baselineY - caplineY)
    }
}

/// A rectangle in template (SVG) coordinate space, with Y increasing downward.
public struct TemplateRect: Codable, Hashable, Sendable {

    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}
