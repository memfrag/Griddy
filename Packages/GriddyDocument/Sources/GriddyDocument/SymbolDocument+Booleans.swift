//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

/// Combining primitives into compound shapes. See spec 10.5.
public extension SymbolDocument {

    /// Why a boolean cannot be formed from the current selection.
    enum CompoundRefusal: Error, Equatable, Sendable {

        case tooFewOperands(Int)
        case containsUneditable
        case wouldCycle

        public var message: String {
            switch self {
            case .tooFewOperands(let count):
                count == 0
                    ? "Select two or more shapes to combine."
                    : "Select at least one more shape — a boolean needs two."
            case .containsUneditable:
                "Some of the selection cannot be edited."
            case .wouldCycle:
                "A shape cannot be combined with something that contains it."
            }
        }
    }

    /// Whether the given selection could be combined.
    ///
    /// Menu items call this rather than attempting and discarding, so the
    /// commands can be disabled with a reason instead of failing on click.
    func canCombine(_ ids: Set<PrimitiveID>) -> CompoundRefusal? {
        guard ids.count >= 2 else {
            return .tooFewOperands(ids.count)
        }
        guard ids.allSatisfy({ isEditable($0) }) else {
            return .containsUneditable
        }
        return nil
    }

    /// Combines the selection into one compound, returning its identifier.
    ///
    /// **Order matters for subtraction.** The result is the first operand minus
    /// the rest, so the operands are taken in draw order rather than in
    /// selection order — a set has no order, and "the first one I clicked" is
    /// not something the document knows. Draw order is what the canvas shows,
    /// so the bottom-most shape is the one subtracted *from*.
    ///
    /// The children stay in the document. They are no longer drawn on their own
    /// — ``resolvedOutline(weight:)`` skips anything a compound claims — but
    /// they remain editable through the compound, and releasing it brings them
    /// back. Deleting them here would make the operation destructive and its
    /// undo a resurrection.
    @discardableResult
    mutating func combinePrimitives(withIDs ids: Set<PrimitiveID>,
                                    operation: CompoundOperation)
    throws(CompoundRefusal) -> PrimitiveID {
        if let refusal = canCombine(ids) {
            throw refusal
        }

        let ordered = primitivesInDrawOrder
            .filter { ids.contains($0.id) }
            .map(\.id)

        // The compound joins the layer of its first operand, so it lands where
        // the shapes it replaces were rather than at the top of the stack.
        let layerID = layer(containing: ordered[0])?.id

        let compound = CompoundPrimitive(operation: operation, children: ordered)
        let primitive = IconPrimitive.compound(compound)

        addPrimitive(primitive, toLayerWithID: layerID)
        return compound.id
    }

    /// Dissolves a compound, returning its children to the drawing.
    ///
    /// The inverse of ``combinePrimitives(withIDs:operation:)``: the children
    /// were never removed, so this only has to remove the wrapper.
    ///
    /// Returns the identifiers that became visible again, so the caller can
    /// select them — releasing a compound and being left with nothing selected
    /// is disorienting.
    @discardableResult
    mutating func releaseCompounds(withIDs ids: Set<PrimitiveID>)
    -> Set<PrimitiveID> {
        var released: Set<PrimitiveID> = []
        var wrappers: Set<PrimitiveID> = []

        for id in ids {
            guard case .compound(let compound)? = primitive(withID: id) else {
                continue
            }
            wrappers.insert(id)
            released.formUnion(compound.children)
        }

        guard !wrappers.isEmpty else {
            return []
        }

        removePrimitives(withIDs: wrappers)

        // A child claimed by another compound is still hidden, so it should not
        // be reported as visible again.
        let stillClaimed = Set(primitivesInDrawOrder.flatMap {
            primitive -> [PrimitiveID] in
            guard case .compound(let compound) = primitive else {
                return []
            }
            return compound.children
        })
        return released.subtracting(stillClaimed)
            .filter { primitive(withID: $0) != nil }
    }

    /// Whether any of these are compounds, so Release can be offered.
    func containsCompound(_ ids: Set<PrimitiveID>) -> Bool {
        ids.contains { id in
            if case .compound? = primitive(withID: id) { true } else { false }
        }
    }
}

// MARK: - Selecting and moving compounds

public extension SymbolDocument {

    /// Primitives a compound has claimed, and which therefore no longer stand
    /// on their own.
    var claimedPrimitiveIDs: Set<PrimitiveID> {
        Set(primitives.flatMap { primitive -> [PrimitiveID] in
            guard case .compound(let compound) = primitive else {
                return []
            }
            // A compound listing itself is ignored rather than allowed to claim
            // itself, which would drop it from the roots and erase the artwork.
            return compound.children.filter { $0 != primitive.id }
        })
    }

    /// The primitives the canvas draws and the user can click: everything not
    /// owned by a compound.
    var rootPrimitivesInDrawOrder: [IconPrimitive] {
        let claimed = claimedPrimitiveIDs
        return primitivesInDrawOrder.filter { !claimed.contains($0.id) }
    }

    /// A primitive's bounds, resolving a compound through its children.
    ///
    /// ``PrimitiveGeometry`` returns nil for a compound because it sees one
    /// primitive at a time and cannot follow child identifiers. Without this a
    /// compound has no bounds, so it draws no selection handles and marquee
    /// selection cannot find it.
    func bounds(of primitive: IconPrimitive) -> IconRect? {
        guard case .compound(let compound) = primitive else {
            return PrimitiveGeometry.bounds(of: primitive)
        }
        return bounds(ofChildren: compound.children, visiting: [primitive.id])
    }

    private func bounds(ofChildren children: [PrimitiveID],
                        visiting: Set<PrimitiveID>) -> IconRect? {
        children.reduce(nil) { result, id -> IconRect? in
            guard !visiting.contains(id),
                  let child = primitive(withID: id) else {
                return result
            }
            let childBounds: IconRect?
            if case .compound(let nested) = child {
                childBounds = bounds(ofChildren: nested.children,
                                     visiting: visiting.union([id]))
            } else {
                childBounds = PrimitiveGeometry.bounds(of: child)
            }
            guard let childBounds else {
                return result
            }
            return result?.union(childBounds) ?? childBounds
        }
    }

    /// The topmost clickable primitive at a point.
    ///
    /// Searches roots only. Hit testing the flat primitive list would find a
    /// compound's children — which are still in the document but no longer
    /// drawn — so clicking a combined shape would select an invisible operand.
    ///
    /// A compound is hit when any of its children is. That over-reports for
    /// subtraction, where the removed region still responds, but it is
    /// predictable and cheap; testing against the resolved outline would mean
    /// outlining and solving on every mouse-down.
    func topmostPrimitive(at point: IconPoint,
                          tolerance: Double) -> IconPrimitive? {
        rootPrimitivesInDrawOrder.last { primitive in
            primitive.attributes.isVisible
                && hit(primitive, at: point, tolerance: tolerance,
                       visiting: [])
        }
    }

    private func hit(_ primitive: IconPrimitive,
                     at point: IconPoint,
                     tolerance: Double,
                     visiting: Set<PrimitiveID>) -> Bool {
        guard case .compound(let compound) = primitive else {
            return HitTesting.hit(primitive, at: point, tolerance: tolerance)
        }
        guard !visiting.contains(primitive.id) else {
            return false
        }
        let visiting = visiting.union([primitive.id])
        return compound.children.contains { id in
            guard let child = self.primitive(withID: id) else {
                return false
            }
            return hit(child, at: point, tolerance: tolerance,
                       visiting: visiting)
        }
    }

    /// Every root primitive whose bounds meet a rectangle, for marquee
    /// selection.
    func rootPrimitives(intersecting rect: IconRect) -> [IconPrimitive] {
        rootPrimitivesInDrawOrder.filter { primitive in
            guard primitive.attributes.isVisible,
                  let bounds = bounds(of: primitive) else {
                return false
            }
            return bounds.intersects(rect)
        }
    }

    /// Translates a selection, carrying a compound's children with it.
    ///
    /// Moving the wrapper alone would do nothing at all: a compound holds no
    /// geometry of its own, only references, so its shape lives entirely in
    /// the children.
    mutating func translateIncludingChildren(withIDs ids: Set<PrimitiveID>,
                                             by vector: IconVector) {
        var toMove = ids
        var frontier = ids

        while !frontier.isEmpty {
            var next: Set<PrimitiveID> = []
            for id in frontier {
                guard case .compound(let compound)? = primitive(withID: id) else {
                    continue
                }
                for child in compound.children where !toMove.contains(child) {
                    toMove.insert(child)
                    next.insert(child)
                }
            }
            frontier = next
        }

        translatePrimitives(withIDs: toMove, by: vector)
    }
}
