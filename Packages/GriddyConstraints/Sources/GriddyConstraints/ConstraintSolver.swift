//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

/// Resolves declared relationships.
///
/// Not a CAD-grade solver, and deliberately so. Constraints here are invariants
/// rather than goals: they restrict what an edit may do, and adding one moves
/// geometry into compliance immediately. Nothing ever needs to search for a
/// solution, so the whole engine is projection and restriction. See spec 11.2.
public enum ConstraintSolver {

    // MARK: Restriction

    /// How far a primitive may be dragged, given the constraints on it.
    public static func restriction(for primitiveID: PrimitiveID,
                                   constraints: [Constraint]) -> DragRestriction {
        var result = DragRestriction.free

        for constraint in constraints
        where constraint.isEnabled && constraint.affectedPrimitiveIDs.contains(primitiveID) {
            result = result.intersected(with: restriction(of: constraint,
                                                          on: primitiveID))
        }
        return result
    }

    /// The restriction a single constraint imposes on one primitive.
    static func restriction(of constraint: Constraint,
                            on primitiveID: PrimitiveID) -> DragRestriction {
        let horizontal = IconVector(dx: 1, dy: 0)
        let vertical = IconVector(dx: 0, dy: 1)

        switch constraint {
        case .centered(let centered):
            // Centred horizontally pins x, leaving only vertical movement.
            switch centered.axis {
            case .horizontal: return .axis(vertical)
            case .vertical: return .axis(horizontal)
            case .both: return .fixed
            }

        case .symmetric(let symmetric):
            // A mirrored pair may slide along the axis but not across it.
            switch symmetric.axis {
            case .vertical: return .axis(vertical)
            case .horizontal: return .axis(horizontal)
            }

        case .fixedDistance, .concentric, .tangent, .onKeyShape:
            // These pin position relative to something else. Treated as fully
            // pinned for dragging; the primitive is repositioned by projection
            // rather than dragged. Sliding a tangent along its tangency is a
            // curved path, which this linear model cannot express.
            return .fixed

        case .onGrid, .equalRadius, .equalLength, .equalSpacing,
             .parallel, .perpendicular, .fixedAngle, .opticalOffset:
            // These constrain size, angle or spacing rather than position, so
            // they leave translation free.
            return .free
        }
    }

    // MARK: Compliance

    /// Moves geometry into compliance with its constraints.
    ///
    /// Applied after an edit so the result always satisfies what was declared.
    /// `pinned` names primitives the caller is holding -- the one under the
    /// cursor -- so the solver adjusts the others around them rather than
    /// undoing the edit the user just made.
    ///
    /// Runs a few passes because constraints interact: making two circles
    /// concentric can move one out of centre, which the centring constraint
    /// then pulls back. Convergence is not guaranteed for a contradictory set,
    /// which is exactly why contradictions are refused at add time instead.
    public static func resolve(primitives: [IconPrimitive],
                               constraints: [Constraint],
                               context: ConstraintContext,
                               pinned: Set<PrimitiveID> = [],
                               passes: Int = 4) -> [IconPrimitive] {
        var byID: [PrimitiveID: IconPrimitive] = [:]
        for primitive in primitives {
            byID[primitive.id] = primitive
        }

        let active = constraints.filter(\.isEnabled)
        guard !active.isEmpty else {
            return primitives
        }

        for _ in 0..<passes {
            for constraint in active {
                apply(constraint, to: &byID, context: context, pinned: pinned)
            }
        }

        // Preserve the caller's ordering; draw order is meaningful.
        return primitives.compactMap { byID[$0.id] }
    }

    private static func apply(_ constraint: Constraint,
                              to primitives: inout [PrimitiveID: IconPrimitive],
                              context: ConstraintContext,
                              pinned: Set<PrimitiveID>) {
        switch constraint {
        case .centered(let centered):
            applyCentered(centered, to: &primitives, context: context)

        case .concentric(let concentric):
            applyShared(concentric.primitiveIDs, in: &primitives, pinned: pinned) {
                $0.anchor
            } set: { primitive, anchor in
                primitive.movingAnchor(to: anchor)
            }

        case .equalRadius(let equal):
            applyShared(equal.primitiveIDs, in: &primitives, pinned: pinned) {
                $0.radius
            } set: { primitive, radius in
                primitive.settingRadius(radius)
            }

        case .parallel(let parallel):
            applyShared(parallel.primitiveIDs, in: &primitives, pinned: pinned) {
                $0.direction
            } set: { primitive, direction in
                primitive.settingDirection(direction)
            }

        case .perpendicular(let perpendicular):
            applyPerpendicular(perpendicular, to: &primitives, pinned: pinned)

        case .symmetric(let symmetric):
            applySymmetric(symmetric, to: &primitives, pinned: pinned)

        case .tangent(let tangent):
            applyTangent(tangent, to: &primitives, pinned: pinned)

        case .onGrid(let onGrid):
            applyOnGrid(onGrid, to: &primitives, context: context)

        case .fixedAngle(let fixedAngle):
            if let primitive = primitives[fixedAngle.primitiveID] {
                primitives[fixedAngle.primitiveID] =
                    primitive.settingDirection(fixedAngle.angle.direction)
            }

        case .onKeyShape, .fixedDistance, .equalLength, .equalSpacing,
             .opticalOffset:
            // Recorded and displayed, but not yet enforced. Each needs a
            // resolution rule that is more than a projection, and enforcing
            // them half-correctly would be worse than not at all.
            break
        }
    }

    // MARK: Individual rules

    private static func applyCentered(_ constraint: CenteredConstraint,
                                      to primitives: inout [PrimitiveID: IconPrimitive],
                                      context: ConstraintContext) {
        guard let primitive = primitives[constraint.primitiveID],
              let anchor = primitive.anchor else {
            return
        }
        let centre = context.canvasBounds.center

        let target = switch constraint.axis {
        case .horizontal: IconPoint(x: centre.x, y: anchor.y)
        case .vertical: IconPoint(x: anchor.x, y: centre.y)
        case .both: centre
        }
        primitives[constraint.primitiveID] = primitive.movingAnchor(to: target)
    }

    /// Makes a group share one value, taken from the pinned member if there is
    /// one and the first member otherwise.
    private static func applyShared<Value>(
        _ ids: [PrimitiveID],
        in primitives: inout [PrimitiveID: IconPrimitive],
        pinned: Set<PrimitiveID>,
        get: (IconPrimitive) -> Value?,
        set: (IconPrimitive, Value) -> IconPrimitive
    ) {
        // Whatever the user is holding wins, so a drag is not undone by the
        // constraint that depends on it.
        let source = ids.first { pinned.contains($0) } ?? ids.first
        guard let source,
              let reference = primitives[source].flatMap(get) else {
            return
        }

        for id in ids where id != source {
            guard let primitive = primitives[id] else {
                continue
            }
            primitives[id] = set(primitive, reference)
        }
    }

    private static func applyPerpendicular(_ constraint: PerpendicularConstraint,
                                           to primitives: inout [PrimitiveID: IconPrimitive],
                                           pinned: Set<PrimitiveID>) {
        let ids = constraint.primitiveIDs
        let source = ids.first { pinned.contains($0) } ?? ids.first
        guard let source,
              let reference = primitives[source]?.direction else {
            return
        }

        for id in ids where id != source {
            guard let primitive = primitives[id] else {
                continue
            }
            primitives[id] = primitive.settingDirection(reference.perpendicular)
        }
    }

    private static func applySymmetric(_ constraint: SymmetricConstraint,
                                       to primitives: inout [PrimitiveID: IconPrimitive],
                                       pinned: Set<PrimitiveID>) {
        let ids = constraint.primitiveIDs
        guard ids.count >= 2 else {
            // A single primitive is symmetric about the axis: centre it there.
            guard let id = ids.first,
                  let primitive = primitives[id],
                  let anchor = primitive.anchor else {
                return
            }
            let target = switch constraint.axis {
            case .vertical: IconPoint(x: constraint.axisPosition, y: anchor.y)
            case .horizontal: IconPoint(x: anchor.x, y: constraint.axisPosition)
            }
            primitives[id] = primitive.movingAnchor(to: target)
            return
        }

        let source = ids.first { pinned.contains($0) } ?? ids[0]
        guard let reference = primitives[source] else {
            return
        }

        for id in ids where id != source {
            guard let primitive = primitives[id] else {
                continue
            }
            primitives[id] = primitive.movingAnchor(
                to: reference.mirrored(across: constraint.axis,
                                       at: constraint.axisPosition).anchor
                    ?? primitive.anchor ?? .zero)
        }
    }

    /// Moves a primitive so it touches its target.
    ///
    /// Handles the circular cases -- circle and arc, which both have a centre
    /// and a radius -- by placing the centres one combined radius apart along
    /// the line already joining them. Tangency involving a line is not resolved
    /// here.
    private static func applyTangent(_ constraint: TangentConstraint,
                                     to primitives: inout [PrimitiveID: IconPrimitive],
                                     pinned: Set<PrimitiveID>) {
        guard !pinned.contains(constraint.primitiveID),
              let moving = primitives[constraint.primitiveID],
              let target = primitives[constraint.targetPrimitiveID],
              let movingRadius = moving.radius,
              let targetRadius = target.radius,
              let movingCentre = moving.anchor,
              let targetCentre = target.anchor else {
            return
        }

        let separation = targetCentre.vector(to: movingCentre)
        guard let direction = separation.normalized else {
            // Concentric: no direction to push along, so pick one rather than
            // leaving the constraint silently unsatisfied.
            primitives[constraint.primitiveID] = moving.movingAnchor(
                to: targetCentre.offset(by: IconVector(dx: movingRadius + targetRadius,
                                                       dy: 0)))
            return
        }

        primitives[constraint.primitiveID] = moving.movingAnchor(
            to: targetCentre.offset(by: direction.scaled(by: movingRadius + targetRadius)))
    }

    private static func applyOnGrid(_ constraint: OnGridConstraint,
                                    to primitives: inout [PrimitiveID: IconPrimitive],
                                    context: ConstraintContext) {
        guard let primitive = primitives[constraint.primitiveID],
              let anchor = primitive.anchor,
              context.gridInterval > .ulpOfOne else {
            return
        }
        let interval = context.gridInterval
        let snapped = IconPoint(x: (anchor.x / interval).rounded() * interval,
                                y: (anchor.y / interval).rounded() * interval)
        primitives[constraint.primitiveID] = primitive.movingAnchor(to: snapped)
    }
}
