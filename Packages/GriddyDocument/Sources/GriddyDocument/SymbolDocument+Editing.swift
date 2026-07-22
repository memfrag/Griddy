//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

/// Semantic edits.
///
/// Every mutation here is one meaningful design action, which is what the undo
/// stack is built from. See spec 16.4.
extension SymbolDocument {

    // MARK: Adding

    /// Adds a primitive and records its membership in a layer.
    ///
    /// Falls back to the first layer when the named one is missing, and creates
    /// a layer if the document somehow has none, so a primitive can never be
    /// added into nowhere and vanish from the canvas.
    public mutating func addPrimitive(_ primitive: IconPrimitive,
                                      toLayerWithID layerID: UUID? = nil) {
        primitives.append(primitive)

        let targetIndex = layerID
            .flatMap { id in layers.firstIndex { $0.id == id } }
            ?? layers.indices.first

        if let targetIndex {
            layers[targetIndex].primitiveIDs.append(primitive.id)
        } else {
            var layer = SymbolLayer(name: "Outer Body", role: .outerBody)
            layer.primitiveIDs = [primitive.id]
            layers.append(layer)
        }
    }

    // MARK: Removing

    /// Removes primitives and every reference to them.
    ///
    /// Also drops constraints that governed them, since a constraint pointing
    /// at geometry that no longer exists cannot be satisfied or displayed.
    public mutating func removePrimitives(withIDs ids: Set<PrimitiveID>) {
        guard !ids.isEmpty else {
            return
        }

        primitives.removeAll { ids.contains($0.id) }

        for index in layers.indices {
            layers[index].primitiveIDs.removeAll { ids.contains($0) }
        }

        constraints.removeAll { constraint in
            constraint.affectedPrimitiveIDs.contains { ids.contains($0) }
        }

        for index in masters.indices {
            masters[index].adjustments.removeAll { ids.contains($0.primitiveID) }
        }
    }

    // MARK: Replacing

    /// Replaces a primitive in place, keeping its position in draw order.
    ///
    /// Draw order is layer order, so replacing rather than remove-and-append
    /// matters: an edited primitive must not jump to the front.
    public mutating func replacePrimitive(_ primitive: IconPrimitive) {
        guard let index = primitives.firstIndex(where: { $0.id == primitive.id }) else {
            return
        }
        primitives[index] = primitive
    }

    // MARK: Moving

    /// Moves primitives by a vector.
    public mutating func translatePrimitives(withIDs ids: Set<PrimitiveID>,
                                             by vector: IconVector) {
        guard !ids.isEmpty else {
            return
        }
        for index in primitives.indices where ids.contains(primitives[index].id) {
            primitives[index] = primitives[index].translated(by: vector)
        }
    }

    // MARK: Querying

    /// The layer that claims a primitive.
    public func layer(containing primitiveID: PrimitiveID) -> SymbolLayer? {
        layers.first { $0.primitiveIDs.contains(primitiveID) }
    }

    /// Primitives in draw order: layer order first, then order within a layer.
    ///
    /// The document's `primitives` array is storage, not z-order. Hit testing
    /// and rendering both need this ordering, and they must agree or the user
    /// selects something other than what they clicked.
    public var primitivesInDrawOrder: [IconPrimitive] {
        var byID: [PrimitiveID: IconPrimitive] = [:]
        for primitive in primitives {
            byID[primitive.id] = primitive
        }

        var ordered: [IconPrimitive] = []
        for layer in layers where layer.isVisible {
            for id in layer.primitiveIDs {
                if let primitive = byID[id] {
                    ordered.append(primitive)
                }
            }
        }
        return ordered
    }

    /// Whether a primitive can be selected and edited.
    public func isEditable(_ primitiveID: PrimitiveID) -> Bool {
        guard let layer = layer(containing: primitiveID) else {
            return false
        }
        return layer.isVisible && !layer.isLocked
    }
}
