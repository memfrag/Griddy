//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

extension SymbolDocument {

    /// The stroke width of a primitive at a given weight, in units.
    ///
    /// This resolves the construction stroke, which is the input to outlining
    /// rather than an exported attribute. See spec 10.3 and 10.5.
    public func strokeWidth(for primitive: IconPrimitive,
                            weight: SymbolWeight) -> Double {
        let base: Double
        switch primitive.attributes.stroke.width {
        case .systemWeight:
            base = exportSettings.weightPropagation.strokeExpansion(for: weight)
        case .fixed(let width):
            base = width
        case .derived(let baseWidth, let scaleFactor):
            base = baseWidth * scaleFactor
        }

        let delta = master(for: weight)?
            .adjustment(for: primitive.id)?
            .strokeWidthDelta ?? 0

        // A negative width is meaningless and would invert the outline.
        return max(0, base + delta)
    }
}
