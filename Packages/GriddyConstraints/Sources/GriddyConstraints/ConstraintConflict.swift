//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

/// Why a constraint cannot be added.
public struct ConstraintConflict: Equatable, Sendable {

    /// The constraint already in place that the new one contradicts.
    public var existing: Constraint

    /// A sentence naming the conflict, for the refusal message.
    public var message: String

    public init(existing: Constraint, message: String) {
        self.existing = existing
        self.message = message
    }
}

extension ConstraintSolver {

    /// Whether a constraint can be added, and what it clashes with if not.
    ///
    /// Because a satisfied constraint can never subsequently drift, conflict
    /// detection only has to happen once, at the moment of addition. That is
    /// far cheaper than checking continuously, and it means a document can
    /// never hold a contradictory set. See spec 11.2.
    public static func conflict(adding candidate: Constraint,
                                to existing: [Constraint]) -> ConstraintConflict? {
        let candidateIDs = Set(candidate.affectedPrimitiveIDs)

        for constraint in existing where constraint.isEnabled {
            let sharedIDs = candidateIDs.intersection(constraint.affectedPrimitiveIDs)
            guard !sharedIDs.isEmpty else {
                continue
            }

            // The same relationship declared twice is a contradiction whenever
            // the two disagree, and redundant when they do not. Either way it
            // should not be added again.
            if sameKind(candidate, constraint) {
                return ConstraintConflict(
                    existing: constraint,
                    message: "\(candidate.displayName) conflicts with the existing "
                        + "\(constraint.displayName) on this geometry."
                )
            }

            // Two constraints that pin the same direction cannot both take
            // effect: whichever resolves second has nothing left to change.
            for id in sharedIDs {
                let candidateRestriction = restriction(of: candidate, on: id)
                let existingRestriction = restriction(of: constraint, on: id)

                if candidateRestriction.pinsSameDirection(as: existingRestriction) {
                    return ConstraintConflict(
                        existing: constraint,
                        message: "\(candidate.displayName) conflicts with "
                            + "\(constraint.displayName), which already determines "
                            + "that position."
                    )
                }
            }
        }
        return nil
    }

    /// Whether two constraints are the same kind of relationship.
    private static func sameKind(_ first: Constraint, _ second: Constraint) -> Bool {
        switch (first, second) {
        case (.onGrid, .onGrid), (.onKeyShape, .onKeyShape),
             (.equalSpacing, .equalSpacing), (.equalRadius, .equalRadius),
             (.equalLength, .equalLength), (.tangent, .tangent),
             (.concentric, .concentric), (.parallel, .parallel),
             (.perpendicular, .perpendicular), (.fixedAngle, .fixedAngle),
             (.fixedDistance, .fixedDistance), (.opticalOffset, .opticalOffset):
            return true

        case (.centered(let a), .centered(let b)):
            // Horizontal and vertical centring coexist happily; they pin
            // different axes. Only an overlapping pair is a conflict.
            return a.axis == b.axis || a.axis == .both || b.axis == .both

        case (.symmetric(let a), .symmetric(let b)):
            return a.axis == b.axis

        default:
            return false
        }
    }

    /// Applies a constraint to geometry that does not yet satisfy it.
    ///
    /// Adding a constraint moves geometry immediately rather than recording an
    /// aspiration, which is what keeps constraints invariants. The caller wraps
    /// this and the constraint record in a single undo step. See spec 11.2.
    public static func snapIntoCompliance(_ constraint: Constraint,
                                          primitives: [IconPrimitive],
                                          existing: [Constraint],
                                          context: ConstraintContext) -> [IconPrimitive] {
        resolve(primitives: primitives,
                constraints: existing + [constraint],
                context: context)
    }
}
