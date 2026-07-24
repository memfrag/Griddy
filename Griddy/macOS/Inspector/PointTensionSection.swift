//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyGeometry
import GriddyDocument

/// Per-point tension for a selected smooth path. See spec 10.5.
///
/// A path point carries a smoothness from 0 (a sharp corner) to 1 (fully
/// round). The corner toggle is the quick either/or; the slider is the
/// continuous control between. The point is chosen by tapping its handle on the
/// canvas.
struct PointTensionSection: View {

    @ObservedObject var file: SymbolDocumentFile
    @Bindable var editor: CanvasEditor
    let polyline: PolylinePrimitive
    @Environment(\.undoManager) private var undoManager

    private var index: Int? {
        guard let index = editor.selectedVertex,
              polyline.points.indices.contains(index) else {
            return nil
        }
        return index
    }

    var body: some View {
        Section("Point") {
            if let index {
                LabeledContent("Point", value: "\(index + 1) of \(polyline.points.count)")

                LabeledContent("Tension") {
                    Slider(value: tensionBinding(index), in: 0...1)
                        .frame(width: 120)
                }

                Button(polyline.smoothness(at: index) > 0.5
                       ? "Make Corner" : "Make Round") {
                    setTension(polyline.smoothness(at: index) > 0.5 ? 0 : 1, at: index)
                }
            } else {
                Text("Click a point on the path to set how sharp or round it is. "
                     + "Option-click a point to toggle it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func tensionBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: { polyline.smoothness(at: index) },
            set: { setTension($0, at: index) }
        )
    }

    private func setTension(_ value: Double, at index: Int) {
        file.perform("Change Tension", undoManager: undoManager) { document in
            guard case .polyline(var updated)? = document.primitive(withID: polyline.id)
            else {
                return
            }
            updated.setSmoothness(value, at: index)
            document.replacePrimitive(.polyline(updated))
        }
    }
}
