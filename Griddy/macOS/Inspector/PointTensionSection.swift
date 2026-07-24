//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyGeometry
import GriddyDocument

/// Per-point control for a selected smooth path. See spec 10.5.
///
/// A point runs in one of three modes. *Symmetric* — one tension from sharp to
/// round, both sides equal. *Per-side* — the arriving and leaving sides set
/// independently, so a point can be round going in and sharp going out.
/// *Free* — explicit tangent handles dragged on the canvas, any direction and
/// length. The point is chosen by tapping its handle.
struct PointTensionSection: View {

    @ObservedObject var file: SymbolDocumentFile
    @Bindable var editor: CanvasEditor
    let polyline: PolylinePrimitive
    @Environment(\.undoManager) private var undoManager

    private enum Mode: String, CaseIterable, Identifiable {
        case symmetric = "Symmetric"
        case perSide = "Per-side"
        case free = "Free"
        var id: Self { self }
    }

    private var index: Int? {
        guard let index = editor.selectedVertex,
              polyline.points.indices.contains(index) else {
            return nil
        }
        return index
    }

    private func mode(at index: Int) -> Mode {
        if polyline.isFree(at: index) { return .free }
        if polyline.isPerSide(at: index) { return .perSide }
        return .symmetric
    }

    var body: some View {
        Section("Point") {
            if let index {
                LabeledContent("Point", value: "\(index + 1) of \(polyline.points.count)")

                Picker("Mode", selection: modeBinding(index)) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch mode(at: index) {
                case .symmetric:
                    tensionSlider("Tension", value: polyline.smoothness(at: index)) {
                        setTension(in: $0, out: $0, at: index)
                    }
                    cornerButton(index)

                case .perSide:
                    tensionSlider("In", value: polyline.smoothness(at: index)) {
                        setTension(in: $0, out: polyline.smoothnessOut(at: index),
                                   at: index)
                    }
                    tensionSlider("Out", value: polyline.smoothnessOut(at: index)) {
                        setTension(in: polyline.smoothness(at: index), out: $0,
                                   at: index)
                    }

                case .free:
                    Text("Drag the two handles on the canvas to shape each side "
                         + "freely.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Click a point on the path to shape it. Option-click a point "
                     + "to toggle it between sharp and round.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func cornerButton(_ index: Int) -> some View {
        Button(polyline.smoothness(at: index) > 0.5 ? "Make Corner" : "Make Round") {
            let value = polyline.smoothness(at: index) > 0.5 ? 0.0 : 1.0
            setTension(in: value, out: value, at: index)
        }
    }

    private func tensionSlider(_ label: String, value: Double,
                               set: @escaping (Double) -> Void) -> some View {
        LabeledContent(label) {
            Slider(value: Binding(get: { value }, set: set), in: 0...1)
                .frame(width: 120)
        }
    }

    // MARK: Editing

    private func modeBinding(_ index: Int) -> Binding<Mode> {
        Binding(
            get: { mode(at: index) },
            set: { newMode in
                // A segmented picker sets its binding during a view update, and
                // `perform` publishes the document change synchronously, which
                // SwiftUI forbids mid-update. Applying it on the next tick moves
                // the mutation out of the update cycle.
                Task { @MainActor in setMode(newMode, at: index) }
            }
        )
    }

    private func setMode(_ mode: Mode, at index: Int) {
        edit("Change Point Mode") { polyline in
            switch mode {
            case .symmetric:
                polyline.setHandle(nil, at: index)
                polyline.setSmoothness(polyline.smoothness(at: index), at: index)
            case .perSide:
                polyline.setHandle(nil, at: index)
                // Leave in/out as they are; the sliders now edit them apart.
            case .free:
                // Seed the handle from the current shape so it does not jump.
                polyline.setHandle(polyline.derivedHandle(at: index), at: index)
            }
        }
    }

    private func setTension(in inValue: Double, out outValue: Double, at index: Int) {
        edit("Change Tension") { $0.setSmoothness(in: inValue, out: outValue, at: index) }
    }

    private func edit(_ name: String, _ mutate: @escaping (inout PolylinePrimitive) -> Void) {
        file.perform(name, undoManager: undoManager) { document in
            guard case .polyline(var updated)? = document.primitive(withID: polyline.id)
            else {
                return
            }
            mutate(&updated)
            document.replacePrimitive(.polyline(updated))
        }
    }
}
