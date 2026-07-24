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

    /// Whether the two sides share one tension. UI-only; the model just stores
    /// equal in/out values when linked.
    @State private var linked = true

    var body: some View {
        Section("Point") {
            if let index {
                LabeledContent("Point", value: "\(index + 1) of \(polyline.points.count)")

                Toggle("Link sides", isOn: $linked)
                    .onChange(of: linked) { _, isLinked in
                        // Linking snaps both sides to the arriving value.
                        if isLinked {
                            setTension(in: polyline.smoothness(at: index),
                                       out: polyline.smoothness(at: index), at: index)
                        }
                    }

                if linked {
                    tensionSlider("Tension", value: polyline.smoothness(at: index)) {
                        setTension(in: $0, out: $0, at: index)
                    }
                } else {
                    tensionSlider("In", value: polyline.smoothness(at: index)) {
                        setTension(in: $0, out: polyline.smoothnessOut(at: index),
                                   at: index)
                    }
                    tensionSlider("Out", value: polyline.smoothnessOut(at: index)) {
                        setTension(in: polyline.smoothness(at: index), out: $0,
                                   at: index)
                    }
                }

                Button(polyline.smoothness(at: index) > 0.5
                       ? "Make Corner" : "Make Round") {
                    setTension(in: polyline.smoothness(at: index) > 0.5 ? 0 : 1,
                               out: polyline.smoothness(at: index) > 0.5 ? 0 : 1,
                               at: index)
                }
            } else {
                Text("Click a point on the path to set how sharp or round it is. "
                     + "Option-click a point to toggle it between sharp and round.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: index) { _, newIndex in
            // Reflect the newly selected point's actual state.
            if let newIndex {
                linked = !polyline.isPerSide(at: newIndex)
            }
        }
        .onAppear {
            if let index { linked = !polyline.isPerSide(at: index) }
        }
    }

    private func tensionSlider(_ label: String, value: Double,
                               set: @escaping (Double) -> Void) -> some View {
        LabeledContent(label) {
            Slider(value: Binding(get: { value }, set: set), in: 0...1)
                .frame(width: 120)
        }
    }

    private func setTension(in inValue: Double, out outValue: Double, at index: Int) {
        file.perform("Change Tension", undoManager: undoManager) { document in
            guard case .polyline(var updated)? = document.primitive(withID: polyline.id)
            else {
                return
            }
            updated.setSmoothness(in: inValue, out: outValue, at: index)
            document.replacePrimitive(.polyline(updated))
        }
    }
}
