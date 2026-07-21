//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyGeometry
import GriddyDocument

/// The drawing canvas.
///
/// Milestone 1 renders the construction layer only. The artwork and evaluation
/// layers arrive with primitive editing and validation. See spec 8.3.
struct SymbolCanvasView: View {

    let document: SymbolDocument

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let transform = CanvasTransform(
                    fitting: document.coordinateSystem.canvasBounds,
                    in: size
                )
                var context = context
                ConstructionLayerRenderer(document: document,
                                          transform: transform)
                    .draw(in: &context)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(PaneBackground())
    }
}

#Preview {
    SymbolCanvasView(
        document: .new(name: "Preview",
                       templateMetrics: .provisionalBlankTemplate,
                       appVersion: "1.0.0")
    )
    .frame(width: 600, height: 500)
}
