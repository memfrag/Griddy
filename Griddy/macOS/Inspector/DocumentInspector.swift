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

    let document: SymbolDocument
    let selection: SidebarSelection?

    var body: some View {
        Form {
            Section("Coordinate System") {
                row("Unit", value: "cap ÷ 16")
                row("1 u", value: "\(format(document.coordinateSystem.unitInTemplateSpace)) tpl")
                row("Canvas", value: "\(format(document.coordinateSystem.canvasBounds.size.width))"
                    + " × \(format(document.coordinateSystem.canvasBounds.size.height)) u")
                row("Cap height",
                    value: format(document.coordinateSystem.templateMetrics.capHeight))
            }

            Section("Grid") {
                row("Primary", value: "\(format(document.grid.primaryInterval)) u")
                row("Secondary", value: "\(format(document.grid.secondaryInterval)) u")
                row("Snap", value: "\(format(document.grid.snapTolerance)) u")
            }

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
