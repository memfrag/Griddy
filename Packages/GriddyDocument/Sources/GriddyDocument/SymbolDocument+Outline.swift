//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

extension SymbolDocument {

    /// The complete filled artwork at a weight, with booleans resolved.
    ///
    /// This is the geometry export writes: constraints resolved, per-master
    /// adjustments applied, primitives outlined, booleans resolved. See
    /// spec 14.5.
    ///
    /// - Note: Resolving booleans is Tier 2 work and must not run per frame.
    ///   The canvas fills each primitive's outline independently instead, which
    ///   for monochrome artwork in one colour is visually identical to the
    ///   union. See spec 15.3.
    public func resolvedOutline(weight: SymbolWeight) -> OutlinePath {
        let exported = primitivesInDrawOrder.filter {
            $0.attributes.isVisible && $0.attributes.participatesInExport
        }

        // Primitives owned by a compound contribute through it, not directly.
        //
        // A compound that lists itself is ignored rather than allowed to claim
        // itself: doing so would drop it from the roots and silently erase the
        // artwork, which is a far worse outcome than tolerating a malformed
        // reference.
        let claimed = Set(exported.flatMap { primitive -> [PrimitiveID] in
            guard case .compound(let compound) = primitive else {
                return []
            }
            return compound.children.filter { $0 != primitive.id }
        })

        let roots = exported.filter { !claimed.contains($0.id) }

        let outlines = roots.compactMap {
            outline(for: $0, weight: weight, visiting: [])
        }
        return BooleanSolver.union(outlines)
    }

    /// The outline of a single primitive, resolving a compound's children.
    ///
    /// `visiting` guards against a compound that reaches itself, which would
    /// otherwise recurse until the stack runs out. A cycle cannot be drawn, so
    /// it resolves to nothing rather than crashing.
    public func outline(for primitive: IconPrimitive,
                        weight: SymbolWeight,
                        visiting: Set<PrimitiveID> = []) -> OutlinePath? {
        guard !visiting.contains(primitive.id) else {
            return nil
        }

        guard case .compound(let compound) = primitive else {
            // Apply this weight's geometry deviation before outlining, so a
            // per-master move or resize is reflected in the exported shape and
            // interpolates through the derived weights. Stroke width is resolved
            // from the original primitive's attributes, not the adjusted copy.
            let shaped = adjusted(primitive, weight: weight)
            return Outliner.outline(shaped,
                                    width: strokeWidth(for: primitive, weight: weight))
        }

        var visiting = visiting
        visiting.insert(primitive.id)

        let childOutlines = compound.children.compactMap { id -> OutlinePath? in
            guard let child = self.primitive(withID: id) else {
                return nil
            }
            return outline(for: child, weight: weight, visiting: visiting)
        }

        guard var result = childOutlines.first else {
            return nil
        }

        for child in childOutlines.dropFirst() {
            result = BooleanSolver.combine(result, child, operation: compound.operation)
        }
        return result
    }
}
