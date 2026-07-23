//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyGeometry

/// Maps Griddy's icon coordinate space onto the view.
///
/// Unit space has its origin at the baseline with Y increasing upward; view
/// space has its origin top left with Y increasing downward. This type owns the
/// flip so no drawing code has to think about it. See spec 9.1.
struct CanvasTransform {

    /// View points per unit.
    let scale: Double

    /// Where unit-space (0, 0) sits in view space.
    let origin: CGPoint

    /// Fits a canvas into `viewSize`, centred, leaving `padding` view points
    /// on every edge.
    init(fitting canvasBounds: IconRect, in viewSize: CGSize, padding: Double = 48) {
        let availableWidth = max(1, viewSize.width - padding * 2)
        let availableHeight = max(1, viewSize.height - padding * 2)

        let widthScale = availableWidth / max(canvasBounds.size.width, 0.001)
        let heightScale = availableHeight / max(canvasBounds.size.height, 0.001)
        let scale = min(widthScale, heightScale)

        self.scale = scale

        let drawnWidth = canvasBounds.size.width * scale
        let drawnHeight = canvasBounds.size.height * scale

        // Centre the canvas, then place the unit-space origin at its bottom
        // left corner.
        self.origin = CGPoint(
            x: (viewSize.width - drawnWidth) / 2 - canvasBounds.minX * scale,
            y: (viewSize.height + drawnHeight) / 2 + canvasBounds.minY * scale
        )
    }

    /// A transform with an explicit scale and origin, for callers that place
    /// the canvas themselves rather than fitting it to a view.
    init(scale: Double, origin: CGPoint) {
        self.scale = scale
        self.origin = origin
    }

    /// A transform that renders a symbol at a text point size.
    ///
    /// SF Symbols are glyphs (§9.5), so a point-size preview means exactly what
    /// it means for text: the cap height occupies a fixed fraction of the point
    /// size. Everything else — advance, overshoot, descenders — scales with it.
    ///
    /// The artwork is centred in a `boxSize`-square cell. It may overflow, and
    /// that is honest: a symbol too heavy to read at 12 pt should look crowded
    /// at 12 pt.
    static func preview(pointSize: Double,
                        boxSize: CGFloat,
                        artworkBounds: IconRect,
                        capHeightFraction: Double = 0.7) -> CanvasTransform {
        // Points per unit: cap height (16 u) maps to a fraction of the point
        // size, the way a font sets a glyph.
        let scale = capHeightFraction * pointSize
            / CoordinateSystem.unitsPerCapHeight

        // Centre the artwork's own bounds in the cell.
        let drawnWidth = artworkBounds.size.width * scale
        let drawnHeight = artworkBounds.size.height * scale
        let originX = (boxSize - drawnWidth) / 2 - artworkBounds.minX * scale
        let originY = (boxSize + drawnHeight) / 2 + artworkBounds.minY * scale

        return CanvasTransform(scale: scale,
                               origin: CGPoint(x: originX, y: originY))
    }

    func point(_ point: IconPoint) -> CGPoint {
        CGPoint(x: origin.x + point.x * scale,
                y: origin.y - point.y * scale)
    }

    func length(_ length: Double) -> CGFloat {
        length * scale
    }

    func rect(_ rect: IconRect) -> CGRect {
        // The unit-space top-left corner is (minX, maxY) because Y is flipped.
        let topLeft = point(IconPoint(x: rect.minX, y: rect.maxY))
        return CGRect(x: topLeft.x,
                      y: topLeft.y,
                      width: length(rect.size.width),
                      height: length(rect.size.height))
    }

    /// Converts a view-space point back into unit space, for hit testing.
    func iconPoint(_ point: CGPoint) -> IconPoint {
        guard scale > .ulpOfOne else {
            return .zero
        }
        return IconPoint(x: (point.x - origin.x) / scale,
                         y: (origin.y - point.y) / scale)
    }
}
