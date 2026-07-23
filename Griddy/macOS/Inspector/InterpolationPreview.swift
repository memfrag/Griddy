//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyGeometry
import GriddyDocument

/// The full nine-weight family, authored anchors and derived intermediates
/// alike. See spec 12.3.
///
/// A designer authors three masters and the other six are derived by rule, but
/// nothing showed those six — the weight where interpolation goes wrong is
/// exactly the one never rendered. This draws all nine, marking which three are
/// authored, so a bad intermediate is visible rather than discovered on export.
struct InterpolationPreview: View {

    let document: SymbolDocument

    private var authored: Set<SymbolWeight> {
        Set(SymbolWeight.authored)
    }

    var body: some View {
        Form {
            Section {
                ForEach(SymbolWeight.allCases, id: \.self) { weight in
                    row(for: weight)
                }
            } header: {
                Text("Interpolation")
            } footer: {
                Text("The three authored masters are marked. The other six are "
                     + "derived by interpolating stroke and geometry between "
                     + "them; this is the only place they are shown.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func row(for weight: SymbolWeight) -> some View {
        LabeledContent {
            WeightThumbnail(document: document, weight: weight)
        } label: {
            HStack(spacing: 6) {
                Text(weight.rawValue.capitalized)
                if authored.contains(weight) {
                    Text("authored")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: Capsule())
                }
            }
        }
    }
}

/// One weight rendered filled, at a fixed thumbnail size.
private struct WeightThumbnail: View {

    let document: SymbolDocument
    let weight: SymbolWeight

    var body: some View {
        Canvas { context, size in
            let outline = document.resolvedOutline(weight: weight)
            guard let bounds = outline.bounds, !outline.isEmpty else {
                return
            }

            // Fit the artwork into the thumbnail rather than by point size:
            // this row compares weights to each other, so a shared frame reads
            // the differences more clearly than true relative sizes would.
            let transform = CanvasTransform(fitting: bounds,
                                            in: size,
                                            padding: 4)
            context.fill(outline.cgPath(transform: transform),
                         with: .color(.primary),
                         style: FillStyle(eoFill: false))
        }
        .frame(width: 44, height: 34)
    }
}
