//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyGeometry
import GriddyDocument

/// How the selected primitive deviates in the active master. See spec 12.5.
///
/// The base primitive is one shape shared across every master; a master stores
/// only the deltas that make its weight look right — a heavier weight often
/// wants its counters opened a touch, a lighter one its details nudged. These
/// deltas were in the model from the start but applied nowhere until now, and
/// there was no way to set them.
///
/// Edits target the toolbar's active master. A derived weight has no master to
/// adjust, but only authored weights are selectable there, so the section is
/// always editing something real.
struct MasterAdjustmentSection: View {

    @ObservedObject var file: SymbolDocumentFile
    @Bindable var editor: CanvasEditor
    let primitive: IconPrimitive
    @Environment(\.undoManager) private var undoManager

    private var document: SymbolDocument { file.document }
    private var weight: SymbolWeight { editor.activeWeight }

    private var adjustment: MasterAdjustment {
        document.master(for: weight)?.adjustment(for: primitive.id)
            ?? MasterAdjustment(primitiveID: primitive.id)
    }

    var body: some View {
        Section {
            LabeledContent("Master", value: weight.rawValue.capitalized)

            unitField("Offset X", value: offset(\.dx))
            unitField("Offset Y", value: offset(\.dy))

            if primitive.radius != nil {
                unitField("Radius Δ", value: delta(\.radiusDelta))
            }
            if primitive.cornerRadius != nil {
                unitField("Corner Δ", value: delta(\.cornerRadiusDelta))
            }

            if !adjustment.isGeometricallyIdentity {
                Button("Reset This Master", role: .destructive) {
                    write(MasterAdjustment(primitiveID: primitive.id,
                                           strokeWidthDelta: adjustment.strokeWidthDelta))
                }
            }
        } header: {
            Text("Master Adjustment")
        } footer: {
            Text("Deviation from the base shape in the \(weight.rawValue.capitalized) "
                 + "master. Intermediate weights interpolate between the masters "
                 + "you set.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Fields

    private func unitField(_ label: String, value: Binding<Double>) -> some View {
        LabeledContent(label) {
            TextField(label, value: value,
                      format: .number.precision(.fractionLength(0...3)))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 72)
        }
    }

    // MARK: Bindings

    private func offset(_ keyPath: WritableKeyPath<IconVector, Double>) -> Binding<Double> {
        Binding(
            get: { adjustment.positionOffset[keyPath: keyPath] },
            set: { new in
                var updated = adjustment
                updated.positionOffset[keyPath: keyPath] = new
                write(updated)
            })
    }

    private func delta(_ keyPath: WritableKeyPath<MasterAdjustment, Double>) -> Binding<Double> {
        Binding(
            get: { adjustment[keyPath: keyPath] },
            set: { new in
                var updated = adjustment
                updated[keyPath: keyPath] = new
                write(updated)
            })
    }

    private func write(_ adjustment: MasterAdjustment) {
        file.perform("Adjust \(weight.rawValue.capitalized) Master",
                     undoManager: undoManager) { document in
            document.setAdjustment(adjustment, weight: weight)
        }
    }
}
