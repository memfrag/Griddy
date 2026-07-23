//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyGeometry
import GriddyDocument

/// One symbol rendered at a text point size. See spec 8.7.
///
/// The strip's whole purpose is small-size feedback, so this draws the resolved
/// outline filled, exactly as the exported symbol would render — not a
/// placeholder, and not the construction-layer stroke the canvas shows. The
/// point size is honoured literally: a 12 pt cell is 12 pt of cap height, so
/// what the eye sees is what a reader would see at that size.
struct SymbolPreview: View {

    let document: SymbolDocument
    let weight: SymbolWeight
    let pointSize: Double

    /// The cell is sized so cap height plus overshoot fits with a little air.
    /// Point sizes are small, so the cell is a generous multiple rather than
    /// the raw point value, which would be a handful of pixels.
    private var boxSize: CGFloat { pointSize * 2 }

    var body: some View {
        VStack(spacing: 6) {
            Text("\(Int(pointSize)) pt")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Canvas { context, size in
                let outline = document.resolvedOutline(weight: weight)
                guard let bounds = outline.bounds, !outline.isEmpty else {
                    return
                }

                let transform = CanvasTransform.preview(
                    pointSize: pointSize,
                    boxSize: size.width,
                    artworkBounds: bounds)

                // Non-zero winding, so an overlap reads as filled and a
                // subtracted hole reads as empty — the same rule the SF Symbols
                // app renders with. `cgPath` closes each contour already.
                let path = outline.cgPath(transform: transform)
                context.fill(path, with: .color(.primary), style: FillStyle(eoFill: false))
            }
            .frame(width: boxSize, height: boxSize)
        }
        .help("\(Int(pointSize)) pt, \(weight.rawValue.capitalized)")
    }
}
