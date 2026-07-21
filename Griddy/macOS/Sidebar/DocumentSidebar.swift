//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyGeometry
import GriddyDocument

/// What the sidebar currently has selected.
///
/// The sidebar mixes construction toggles, layers and masters, so selection is
/// an enum rather than a single model type. See spec 8.2.
enum SidebarSelection: Hashable {
    case symbol
    case grid
    case keyShape(UUID)
    case layer(UUID)
    case master(UUID)
}

/// The document structure sidebar. See spec 8.2.
struct DocumentSidebar: View {

    @Binding var document: SymbolDocument
    @Binding var selection: SidebarSelection?

    var body: some View {
        List(selection: $selection) {
            Section("Symbol") {
                Label(document.metadata.name, systemImage: "square.on.square.dashed")
                    .tag(SidebarSelection.symbol)
            }

            Section("Construction") {
                Label("\(gridDescription) Grid", systemImage: "grid")
                    .tag(SidebarSelection.grid)
                Toggle("Primary Grid", isOn: $document.grid.showsPrimaryGrid)
                Toggle("Secondary Grid", isOn: $document.grid.showsSecondaryGrid)
            }

            Section("Key Shapes") {
                ForEach(document.keyShapes.all) { keyShape in
                    Label(keyShape.name, systemImage: symbolName(for: keyShape.kind))
                        .tag(SidebarSelection.keyShape(keyShape.id))
                }
            }

            Section("Layers") {
                ForEach(document.layers) { layer in
                    Label(layer.name, systemImage: symbolName(for: layer.role))
                        .tag(SidebarSelection.layer(layer.id))
                }
            }

            Section("Masters") {
                ForEach(document.masters) { master in
                    Label(master.weight.rawValue.capitalized,
                          systemImage: "circle.lefthalf.filled")
                        .tag(SidebarSelection.master(master.id))
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200, idealWidth: 220, maxWidth: 320)
    }

    private var gridDescription: String {
        let rows = Int(CoordinateSystem.unitsPerCapHeight)
        return "\(rows) × \(rows)"
    }

    private func symbolName(for kind: KeyShapeKind) -> String {
        switch kind {
        case .circle: "circle"
        case .square: "square"
        case .horizontalRectangle: "rectangle"
        case .verticalRectangle: "rectangle.portrait"
        case .customPath: "scribble"
        }
    }

    private func symbolName(for role: SymbolLayerRole) -> String {
        switch role {
        case .outerBody: "circle"
        case .detail: "scribble"
        case .badge: "seal"
        case .cutout: "circle.dashed"
        case .annotation: "text.bubble"
        }
    }
}
