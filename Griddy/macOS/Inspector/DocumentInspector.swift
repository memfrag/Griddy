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

            Section("Grid") {
                row("Primary", value: "\(format(document.grid.primaryInterval)) u")
                row("Secondary", value: "\(format(document.grid.secondaryInterval)) u")
                row("Snap", value: "\(format(document.grid.snapTolerance)) u")
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

    private func format(_ value: Double) -> String {
        value == value.rounded()
            ? String(Int(value))
            : String(format: "%.3g", value)
    }
}
