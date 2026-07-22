//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry
import GriddyConstraints

/// Thrown when a constraint cannot be added.
public struct ConstraintRejected: Error, Equatable {

    public var conflict: ConstraintConflict

    public var message: String {
        conflict.message
    }
}

extension SymbolDocument {

    /// The facts the constraint solver needs from this document.
    public var constraintContext: ConstraintContext {
        ConstraintContext(
            canvasBounds: coordinateSystem.canvasBounds,
            keyShapeBounds: Dictionary(
                keyShapes.all.map { ($0.id, $0.bounds) },
                uniquingKeysWith: { first, _ in first }
            ),
            gridInterval: grid.secondaryInterval
        )
    }

    /// How far a primitive may be dragged.
    ///
    /// Applied to the drag's input rather than checked afterwards, which is
    /// what makes a constraint an invariant. See spec 11.2.
    public func dragRestriction(for primitiveID: PrimitiveID) -> DragRestriction {
        ConstraintSolver.restriction(for: primitiveID, constraints: constraints)
    }

    /// Moves geometry back into compliance after an edit.
    ///
    /// `pinned` names the primitives the user is holding, so the solver adjusts
    /// what depends on them rather than undoing the edit itself.
    public mutating func resolveConstraints(pinned: Set<PrimitiveID> = []) {
        guard !constraints.isEmpty else {
            return
        }
        primitives = ConstraintSolver.resolve(primitives: primitives,
                                              constraints: constraints,
                                              context: constraintContext,
                                              pinned: pinned)
    }

    /// Adds a constraint, moving geometry into compliance in the same step.
    ///
    /// Throws rather than recording a constraint that contradicts an existing
    /// one: a document should never hold a contradictory set, which is what
    /// lets everything downstream assume constraints simply hold. See
    /// spec 11.2.
    public mutating func addConstraint(_ constraint: Constraint) throws {
        if let conflict = ConstraintSolver.conflict(adding: constraint,
                                                    to: constraints) {
            throw ConstraintRejected(conflict: conflict)
        }

        primitives = ConstraintSolver.snapIntoCompliance(
            constraint,
            primitives: primitives,
            existing: constraints,
            context: constraintContext
        )
        constraints.append(constraint)
    }

    /// Removes a constraint by identity.
    public mutating func removeConstraint(withID id: ConstraintID) {
        constraints.removeAll { $0.id == id }
    }

    /// Enables or disables a constraint without discarding it.
    ///
    /// Disabling is how a user escapes an invariant while keeping the
    /// relationship on record. See spec 11.3.
    public mutating func setConstraint(_ id: ConstraintID, enabled: Bool) {
        guard let index = constraints.firstIndex(where: { $0.id == id }) else {
            return
        }
        constraints[index] = constraints[index].settingEnabled(enabled)
    }
}
