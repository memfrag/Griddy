//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyGeometry
import GriddyDocument

/// The right-hand inspector.
///
/// Milestone 1 shows document-level facts. The four semantic tabs (Geometry,
/// Constraints, Master, Export) arrive with primitive editing. See spec 8.6.
struct DocumentInspector: View {

    @ObservedObject var file: SymbolDocumentFile
    @Bindable var editor: CanvasEditor
    let selection: SidebarSelection?
    @Environment(\.undoManager) private var undoManager

    private var document: SymbolDocument {
        file.document
    }

    var body: some View {
        if let primitive = selectedPrimitive {
            PrimitiveInspector(file: file, editor: editor, primitive: primitive)
        } else if editor.selection.count > 1 {
            multipleSelection
        } else if case .master = selection {
            // Selecting a master in the sidebar shows the whole interpolated
            // family, which is where the derived weights become visible.
            InterpolationPreview(document: document)
        } else {
            documentProperties
        }
    }

    /// The single selected primitive, if exactly one is selected.
    private var selectedPrimitive: IconPrimitive? {
        guard editor.selection.count == 1, let id = editor.selection.first else {
            return nil
        }
        return document.primitive(withID: id)
    }

    private var multipleSelection: some View {
        ContentUnavailableView {
            Label("\(editor.selection.count) Primitives", systemImage: "square.on.square")
        } description: {
            Text("Select a single primitive to edit its properties.")
        }
    }

    private var documentProperties: some View {
        Form {
            Section("Coordinate System") {
                row("Unit", value: "cap ÷ 16")
                row("1 u", value: "\(format(document.coordinateSystem.unitInTemplateSpace)) tpl")
                row("Design area", value: "\(format(document.coordinateSystem.designArea.size.width))"
                    + " × \(format(document.coordinateSystem.designArea.size.height)) u")
                row("Cap height",
                    value: format(document.coordinateSystem.templateMetrics.capHeight))
            }

            Section("Grid & Snapping") {
                Toggle("Snap to grid", isOn: snapsToGridBinding)

                Stepper(value: subdivisionsBinding, in: 1...16) {
                    LabeledContent("Subdivisions") {
                        Text("\(document.grid.secondaryDivisions)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .disabled(!document.grid.snapsToGrid)

                row("Snap step", value: "\(format(document.grid.secondaryInterval)) u")

                LabeledContent("Snap distance") {
                    TextField("Distance", value: snapDistanceBinding,
                              format: .number.precision(.fractionLength(0...3)))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .frame(width: 72)
                }
                .disabled(!document.grid.snapsToGrid)
            }

            MarginSection(file: file, editor: editor)

            Section("Export") {
                row("Authored masters", value: "\(document.masters.count)")
                row("Exported slots", value: "\(SymbolSlot.all.count)")
                row("Design intent",
                    value: document.metadata.designIntent.rawValue.capitalized)
            }

            Section("Document") {
                row("Format version", value: "\(document.metadata.documentFormatVersion)")
                row("Primitives", value: "\(document.primitives.count)")
                row("Layers", value: "\(document.layers.count)")
                row("Constraints", value: "\(document.constraints.count)")
            }
        }
        .formStyle(.grouped)
    }

    private func row(_ label: String, value: String) -> some View {
        LabeledContent(label) {
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: Grid bindings

    private var snapsToGridBinding: Binding<Bool> {
        gridBinding(\.snapsToGrid, name: "Toggle Snapping")
    }

    private var subdivisionsBinding: Binding<Int> {
        Binding(
            get: { document.grid.secondaryDivisions },
            set: { newValue in
                editGrid("Change Subdivisions") {
                    $0.secondaryDivisions = max(1, newValue)
                }
            }
        )
    }

    private var snapDistanceBinding: Binding<Double> {
        Binding(
            get: { document.grid.snapTolerance },
            set: { newValue in
                editGrid("Change Snap Distance") {
                    $0.snapTolerance = max(0, newValue)
                }
            }
        )
    }

    private func gridBinding(_ keyPath: WritableKeyPath<GridDefinition, Bool>,
                            name: String) -> Binding<Bool> {
        Binding(
            get: { document.grid[keyPath: keyPath] },
            set: { newValue in
                editGrid(name) { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    private func editGrid(_ name: String,
                          _ mutate: @escaping (inout GridDefinition) -> Void) {
        file.perform(name, undoManager: undoManager) { document in
            mutate(&document.grid)
        }
    }

    private func format(_ value: Double) -> String {
        value == value.rounded()
            ? String(Int(value))
            : String(format: "%.3g", value)
    }
}
