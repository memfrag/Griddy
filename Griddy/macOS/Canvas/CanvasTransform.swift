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
