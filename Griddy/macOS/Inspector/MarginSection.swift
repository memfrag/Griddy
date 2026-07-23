//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyGeometry
import GriddyDocument

/// The symbol's horizontal metrics, per weight. See spec 9.5.
///
/// Margins are otherwise invisible: they are computed at export from the
/// artwork and shown nowhere on the canvas as numbers. A designer who wants the
/// tighter trailing margin Apple's own symbols use (takeoutbag: 6.67, 4.09,
/// 2.36 against a 9.77 default) has no way to ask for it without this.
struct MarginSection: View {

    @ObservedObject var file: SymbolDocumentFile
    @Bindable var editor: CanvasEditor
    @Environment(\.undoManager) private var undoManager

    private var document: SymbolDocument { file.document }

    /// The weight whose metrics are shown, following the canvas's active
    /// master so the numbers match the guides on screen.
    private var weight: SymbolWeight { editor.activeWeight }

    private var resolved: ResolvedMargins {
        ResolvedMargins.resolve(
            outline: document.resolvedOutline(weight: weight),
            weight: weight,
            margins: document.margins,
            coordinateSystem: document.coordinateSystem)
    }

    private var isOverridden: Bool {
        document.margins.overrides[weight] != nil
    }

    var body: some View {
        Section {
            LabeledContent("Master", value: weight.rawValue.capitalized)

            unitRow("Advance", value: resolved.advance)
            unitField("Left bearing", binding: leftBearingBinding)
            unitField("Right bearing", binding: rightBearingBinding)

            if isOverridden {
                Button("Reset to Standard", role: .destructive) {
                    edit("Reset Margins") { $0.clearOverride(for: weight) }
                }
            }
        } header: {
            Text("Margins")
        } footer: {
            Text(footer)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: String {
        if isOverridden {
            return "Overridden for \(weight.rawValue.capitalized). The advance "
                + "still follows the artwork; only the bearings are fixed."
        }
        let standard = format(document.coordinateSystem.standardSideBearing)
        return "Computed from the artwork, with the standard \(standard) u "
            + "bearing on each side. Editing a bearing overrides it for this "
            + "master only."
    }

    // MARK: Rows

    private func unitRow(_ label: String, value: Double) -> some View {
        LabeledContent(label) {
            Text("\(format(value)) u")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func unitField(_ label: String,
                           binding: Binding<Double>) -> some View {
        LabeledContent(label) {
            TextField(label, value: binding, format: .number.precision(
                .fractionLength(0...3)))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 72)
        }
    }

    // MARK: Bindings

    /// A bearing binding that overrides on write.
    ///
    /// Reading returns the effective value — the override, or the standard —
    /// so an un-overridden field still shows a real number rather than a blank.
    /// Writing establishes the override, seeding the other bearing with its
    /// current effective value so it is not silently zeroed.
    private var leftBearingBinding: Binding<Double> {
        bearingBinding(get: \.leftSideBearing) { current, new in
            GlyphMetrics(leftSideBearing: new,
                         rightSideBearing: current.rightSideBearing)
        }
    }

    private var rightBearingBinding: Binding<Double> {
        bearingBinding(get: \.rightSideBearing) { current, new in
            GlyphMetrics(leftSideBearing: current.leftSideBearing,
                         rightSideBearing: new)
        }
    }

    private func bearingBinding(
        get keyPath: KeyPath<GlyphMetrics, Double>,
        set combine: @escaping (GlyphMetrics, Double) -> GlyphMetrics
    ) -> Binding<Double> {
        Binding(
            get: {
                document.margins.metrics(for: weight,
                                         in: document.coordinateSystem)[keyPath: keyPath]
            },
            set: { new in
                let current = document.margins.metrics(
                    for: weight, in: document.coordinateSystem)
                edit("Change Margin") {
                    $0.override(combine(current, max(0, new)), for: weight)
                }
            })
    }

    private func edit(_ name: String, _ mutate: @escaping (inout SymbolMargins) -> Void) {
        file.perform(name, undoManager: undoManager) { document in
            mutate(&document.margins)
        }
    }

    private func format(_ value: Double) -> String {
        value == value.rounded()
            ? String(Int(value))
            : String(format: "%.3g", value)
    }
}
