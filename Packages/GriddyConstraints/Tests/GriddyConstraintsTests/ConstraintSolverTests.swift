//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
import GriddyGeometry
@testable import GriddyConstraints

private let canvas = IconRect(x: 0, y: 0, width: 16, height: 16)
private let context = ConstraintContext(canvasBounds: canvas)

private func approximately(_ value: Double,
                           _ expected: Double,
                           tolerance: Double = 1e-9) -> Bool {
    abs(value - expected) <= tolerance
}

private let horizontal = IconVector(dx: 1, dy: 0)
private let vertical = IconVector(dx: 0, dy: 1)

@Suite("Drag restriction")
struct DragRestrictionTests {

    @Test("Free composed with anything yields the other")
    func freeIsIdentity() {
        #expect(DragRestriction.free.intersected(with: .fixed) == .fixed)
        #expect(DragRestriction.free.intersected(with: .axis(vertical))
                == .axis(vertical))
        #expect(DragRestriction.axis(vertical).intersected(with: .free)
                == .axis(vertical))
    }

    @Test("Fixed composed with anything stays fixed")
    func fixedAbsorbs() {
        #expect(DragRestriction.fixed.intersected(with: .free) == .fixed)
        #expect(DragRestriction.fixed.intersected(with: .axis(horizontal)) == .fixed)
    }

    @Test("Crossing axes leave no freedom at all")
    func crossingAxes() {
        #expect(DragRestriction.axis(horizontal).intersected(with: .axis(vertical))
                == .fixed)
    }

    @Test("Parallel axes compose to the same freedom, whichever way they point")
    func parallelAxes() {
        let reversed = IconVector(dx: -1, dy: 0)
        #expect(DragRestriction.axis(horizontal).intersected(with: .axis(reversed))
                == .axis(horizontal))
    }

    @Test("Applying a restriction projects the movement")
    func projection() {
        let movement = IconVector(dx: 3, dy: 4)

        #expect(DragRestriction.free.apply(to: movement) == movement)
        #expect(DragRestriction.fixed.apply(to: movement) == .zero)

        let vertically = DragRestriction.axis(vertical).apply(to: movement)
        #expect(approximately(vertically.dx, 0), "horizontal movement is discarded")
        #expect(approximately(vertically.dy, 4))
    }

    @Test("A horizontally centred primitive may only move vertically")
    func centredHorizontally() {
        let id = PrimitiveID()
        let constraint = Constraint.centered(
            CenteredConstraint(primitiveID: id, axis: .horizontal))

        let restriction = ConstraintSolver.restriction(for: id,
                                                       constraints: [constraint])
        let moved = restriction.apply(to: IconVector(dx: 5, dy: 2))

        #expect(approximately(moved.dx, 0))
        #expect(approximately(moved.dy, 2))
    }

    @Test("Centring on both axes pins the primitive entirely")
    func centredBoth() {
        let id = PrimitiveID()
        let constraint = Constraint.centered(
            CenteredConstraint(primitiveID: id, axis: .both))

        #expect(ConstraintSolver.restriction(for: id, constraints: [constraint])
                == .fixed)
    }

    @Test("Constraints on other primitives do not restrict this one")
    func unrelatedConstraints() {
        let id = PrimitiveID()
        let other = PrimitiveID()
        let constraint = Constraint.centered(
            CenteredConstraint(primitiveID: other, axis: .both))

        #expect(ConstraintSolver.restriction(for: id, constraints: [constraint])
                == .free)
    }

    @Test("A disabled constraint imposes nothing")
    func disabledConstraint() {
        let id = PrimitiveID()
        var body = CenteredConstraint(primitiveID: id, axis: .both)
        body.isEnabled = false

        #expect(ConstraintSolver.restriction(for: id,
                                             constraints: [.centered(body)]) == .free)
    }

    @Test("Size and angle constraints leave translation free")
    func nonPositionalConstraints() {
        let id = PrimitiveID()
        let other = PrimitiveID()

        let constraints: [Constraint] = [
            .equalRadius(EqualRadiusConstraint(primitiveIDs: [id, other])),
            .parallel(ParallelConstraint(primitiveIDs: [id, other])),
            .onGrid(OnGridConstraint(primitiveID: id))
        ]

        for constraint in constraints {
            #expect(ConstraintSolver.restriction(for: id, constraints: [constraint])
                    == .free, "\(constraint.displayName) should not pin position")
        }
    }
}

@Suite("Compliance projection")
struct ComplianceTests {

    private func circle(at point: IconPoint, radius: Double = 2) -> CirclePrimitive {
        CirclePrimitive(center: point, radius: radius)
    }

    @Test("Centring moves a primitive onto the canvas axis")
    func centring() throws {
        let subject = circle(at: IconPoint(x: 3, y: 5))
        let resolved = ConstraintSolver.resolve(
            primitives: [.circle(subject)],
            constraints: [.centered(CenteredConstraint(primitiveID: subject.id,
                                                       axis: .horizontal))],
            context: context)

        let anchor = try #require(resolved.first?.anchor)
        #expect(approximately(anchor.x, 8), "moved to the canvas centre line")
        #expect(approximately(anchor.y, 5), "the other axis is untouched")
    }

    @Test("Centring on both axes lands on the canvas centre")
    func centringBoth() throws {
        let subject = circle(at: IconPoint(x: 3, y: 5))
        let resolved = ConstraintSolver.resolve(
            primitives: [.circle(subject)],
            constraints: [.centered(CenteredConstraint(primitiveID: subject.id,
                                                       axis: .both))],
            context: context)

        let anchor = try #require(resolved.first?.anchor)
        #expect(approximately(anchor.x, 8))
        #expect(approximately(anchor.y, 8))
    }

    @Test("Concentric primitives end up sharing a centre")
    func concentric() throws {
        let first = circle(at: IconPoint(x: 4, y: 4), radius: 3)
        let second = circle(at: IconPoint(x: 9, y: 7), radius: 1)

        let resolved = ConstraintSolver.resolve(
            primitives: [.circle(first), .circle(second)],
            constraints: [.concentric(ConcentricConstraint(
                primitiveIDs: [first.id, second.id]))],
            context: context)

        let anchors = resolved.compactMap(\.anchor)
        #expect(anchors.count == 2)
        #expect(approximately(anchors[0].x, anchors[1].x))
        #expect(approximately(anchors[0].y, anchors[1].y))
        #expect(approximately(anchors[1].x, 4), "the first member is the reference")
    }

    @Test("A pinned primitive is the one others follow")
    func pinnedWins() throws {
        let first = circle(at: IconPoint(x: 4, y: 4))
        let second = circle(at: IconPoint(x: 9, y: 7))

        // The user is dragging the second, so it must not be yanked back.
        let resolved = ConstraintSolver.resolve(
            primitives: [.circle(first), .circle(second)],
            constraints: [.concentric(ConcentricConstraint(
                primitiveIDs: [first.id, second.id]))],
            context: context,
            pinned: [second.id])

        let anchors = resolved.compactMap(\.anchor)
        #expect(approximately(anchors[0].x, 9), "the held primitive stayed put")
        #expect(approximately(anchors[1].x, 9))
    }

    @Test("Equal radius propagates from the reference")
    func equalRadius() {
        let first = circle(at: IconPoint(x: 4, y: 4), radius: 3)
        let second = circle(at: IconPoint(x: 10, y: 10), radius: 1)

        let resolved = ConstraintSolver.resolve(
            primitives: [.circle(first), .circle(second)],
            constraints: [.equalRadius(EqualRadiusConstraint(
                primitiveIDs: [first.id, second.id]))],
            context: context)

        #expect(resolved.compactMap(\.radius) == [3, 3])
    }

    @Test("Parallel lines end up pointing the same way")
    func parallel() throws {
        let first = LinePrimitive(start: .zero, end: IconPoint(x: 4, y: 0))
        let second = LinePrimitive(start: IconPoint(x: 0, y: 5),
                                   end: IconPoint(x: 0, y: 9))

        let resolved = ConstraintSolver.resolve(
            primitives: [.line(first), .line(second)],
            constraints: [.parallel(ParallelConstraint(
                primitiveIDs: [first.id, second.id]))],
            context: context)

        let directions = resolved.compactMap(\.direction)
        #expect(directions.count == 2)
        #expect(approximately(abs(directions[0].dot(directions[1])), 1),
                "the two lines are parallel")
    }

    @Test("Perpendicular lines end up at a right angle")
    func perpendicular() throws {
        let first = LinePrimitive(start: .zero, end: IconPoint(x: 4, y: 0))
        let second = LinePrimitive(start: IconPoint(x: 0, y: 5),
                                   end: IconPoint(x: 4, y: 5))

        let resolved = ConstraintSolver.resolve(
            primitives: [.line(first), .line(second)],
            constraints: [.perpendicular(PerpendicularConstraint(
                primitiveIDs: [first.id, second.id]))],
            context: context)

        let directions = resolved.compactMap(\.direction)
        #expect(directions.count == 2)
        #expect(approximately(directions[0].dot(directions[1]), 0, tolerance: 1e-9),
                "the two lines meet at a right angle")
    }

    @Test("Rotating a line about its midpoint preserves its length")
    func rotationPreservesLength() throws {
        let line = LinePrimitive(start: .zero, end: IconPoint(x: 6, y: 0))
        let resolved = ConstraintSolver.resolve(
            primitives: [.line(line)],
            constraints: [.fixedAngle(FixedAngleConstraint(
                primitiveID: line.id, angle: IconAngle(degrees: 45)))],
            context: context)

        guard case .line(let rotated) = try #require(resolved.first) else {
            Issue.record("Expected a line")
            return
        }
        #expect(approximately(rotated.length, 6))
    }

    @Test("Tangent circles end up touching")
    func tangent() throws {
        let target = circle(at: IconPoint(x: 5, y: 5), radius: 3)
        let moving = circle(at: IconPoint(x: 12, y: 5), radius: 1)

        let resolved = ConstraintSolver.resolve(
            primitives: [.circle(target), .circle(moving)],
            constraints: [.tangent(TangentConstraint(
                primitiveID: moving.id, targetPrimitiveID: target.id))],
            context: context)

        let anchors = resolved.compactMap(\.anchor)
        let separation = anchors[0].distance(to: anchors[1])
        #expect(approximately(separation, 4), "centres one combined radius apart")
    }

    @Test("On-grid snaps the anchor to the interval")
    func onGrid() throws {
        let subject = circle(at: IconPoint(x: 3.31, y: 5.87))
        let resolved = ConstraintSolver.resolve(
            primitives: [.circle(subject)],
            constraints: [.onGrid(OnGridConstraint(primitiveID: subject.id))],
            context: ConstraintContext(canvasBounds: canvas, gridInterval: 0.25))

        let anchor = try #require(resolved.first?.anchor)
        #expect(approximately(anchor.x, 3.25))
        #expect(approximately(anchor.y, 5.75))
    }

    @Test("Resolution is idempotent: already-compliant geometry does not move")
    func idempotence() throws {
        let subject = circle(at: IconPoint(x: 8, y: 8))
        let constraints: [Constraint] = [
            .centered(CenteredConstraint(primitiveID: subject.id, axis: .both))
        ]

        let once = ConstraintSolver.resolve(primitives: [.circle(subject)],
                                            constraints: constraints,
                                            context: context)
        let twice = ConstraintSolver.resolve(primitives: once,
                                             constraints: constraints,
                                             context: context)
        #expect(once == twice)
    }

    @Test("Compatible constraints settle together")
    func multipleConstraints() throws {
        // Centred vertically and made equal-radius: neither fights the other.
        let first = circle(at: IconPoint(x: 4, y: 2), radius: 3)
        let second = circle(at: IconPoint(x: 11, y: 13), radius: 1)

        let resolved = ConstraintSolver.resolve(
            primitives: [.circle(first), .circle(second)],
            constraints: [
                .centered(CenteredConstraint(primitiveID: first.id, axis: .vertical)),
                .equalRadius(EqualRadiusConstraint(
                    primitiveIDs: [first.id, second.id]))
            ],
            context: context)

        let anchor = try #require(resolved.first?.anchor)
        #expect(approximately(anchor.y, 8), "centred vertically")
        #expect(resolved.compactMap(\.radius) == [3, 3], "radii equalised")
    }

    @Test("Resolution preserves ordering and identity")
    func preservesOrder() {
        let first = circle(at: IconPoint(x: 2, y: 2))
        let second = circle(at: IconPoint(x: 9, y: 9))
        let input: [IconPrimitive] = [.circle(first), .circle(second)]

        let resolved = ConstraintSolver.resolve(
            primitives: input,
            constraints: [.concentric(ConcentricConstraint(
                primitiveIDs: [first.id, second.id]))],
            context: context)

        #expect(resolved.map(\.id) == input.map(\.id),
                "draw order must survive resolution")
    }

    @Test("With no constraints, nothing changes")
    func noConstraints() {
        let input: [IconPrimitive] = [.circle(circle(at: IconPoint(x: 3, y: 3)))]
        #expect(ConstraintSolver.resolve(primitives: input,
                                         constraints: [],
                                         context: context) == input)
    }
}

@Suite("Conflict detection")
struct ConflictTests {

    private let subject = PrimitiveID()
    private let other = PrimitiveID()

    @Test("The same relationship twice is refused")
    func duplicateConstraint() throws {
        let existing = Constraint.centered(
            CenteredConstraint(primitiveID: subject, axis: .horizontal))
        let candidate = Constraint.centered(
            CenteredConstraint(primitiveID: subject, axis: .horizontal))

        let conflict = try #require(
            ConstraintSolver.conflict(adding: candidate, to: [existing]))
        #expect(conflict.existing == existing)
        #expect(!conflict.message.isEmpty)
    }

    @Test("Horizontal and vertical centring coexist")
    func complementaryAxes() {
        let existing = Constraint.centered(
            CenteredConstraint(primitiveID: subject, axis: .horizontal))
        let candidate = Constraint.centered(
            CenteredConstraint(primitiveID: subject, axis: .vertical))

        #expect(ConstraintSolver.conflict(adding: candidate, to: [existing]) == nil,
                "these pin different axes and are compatible")
    }

    @Test("Centring on both axes conflicts with centring on one")
    func overlappingAxes() {
        let existing = Constraint.centered(
            CenteredConstraint(primitiveID: subject, axis: .horizontal))
        let candidate = Constraint.centered(
            CenteredConstraint(primitiveID: subject, axis: .both))

        #expect(ConstraintSolver.conflict(adding: candidate, to: [existing]) != nil)
    }

    @Test("A constraint that pins an already-pinned position is refused")
    func pinnedPositionConflict() throws {
        // Fixed distance fully determines position, so centring has nothing
        // left to decide. This is the example from the specification.
        let existing = Constraint.fixedDistance(
            FixedDistanceConstraint(primitiveID: subject,
                                    targetPrimitiveID: other,
                                    distance: 3))
        let candidate = Constraint.centered(
            CenteredConstraint(primitiveID: subject, axis: .horizontal))

        let conflict = try #require(
            ConstraintSolver.conflict(adding: candidate, to: [existing]))
        #expect(conflict.existing == existing)
        #expect(conflict.message.contains("Fixed distance"))
    }

    @Test("Constraints on unrelated geometry never conflict")
    func unrelatedGeometry() {
        let existing = Constraint.centered(
            CenteredConstraint(primitiveID: other, axis: .horizontal))
        let candidate = Constraint.centered(
            CenteredConstraint(primitiveID: subject, axis: .horizontal))

        #expect(ConstraintSolver.conflict(adding: candidate, to: [existing]) == nil)
    }

    @Test("A disabled constraint cannot conflict")
    func disabledDoesNotConflict() {
        var body = CenteredConstraint(primitiveID: subject, axis: .horizontal)
        body.isEnabled = false

        let candidate = Constraint.centered(
            CenteredConstraint(primitiveID: subject, axis: .horizontal))

        #expect(ConstraintSolver.conflict(adding: candidate,
                                          to: [.centered(body)]) == nil)
    }

    @Test("Constraints of different kinds on different axes coexist")
    func compatibleDifferentKinds() {
        let existing = Constraint.equalRadius(
            EqualRadiusConstraint(primitiveIDs: [subject, other]))
        let candidate = Constraint.centered(
            CenteredConstraint(primitiveID: subject, axis: .horizontal))

        #expect(ConstraintSolver.conflict(adding: candidate, to: [existing]) == nil,
                "one constrains size, the other position")
    }

    @Test("Adding to an empty set never conflicts")
    func emptySet() {
        let candidate = Constraint.centered(
            CenteredConstraint(primitiveID: subject, axis: .both))
        #expect(ConstraintSolver.conflict(adding: candidate, to: []) == nil)
    }
}

@Suite("Snapping into compliance")
struct SnapIntoComplianceTests {

    @Test("Adding a constraint moves geometry immediately")
    func snapsOnAdd() throws {
        let subject = CirclePrimitive(center: IconPoint(x: 3, y: 5), radius: 2)
        let constraint = Constraint.centered(
            CenteredConstraint(primitiveID: subject.id, axis: .horizontal))

        let resolved = ConstraintSolver.snapIntoCompliance(
            constraint,
            primitives: [.circle(subject)],
            existing: [],
            context: context)

        let anchor = try #require(resolved.first?.anchor)
        #expect(approximately(anchor.x, 8),
                "the constraint took effect at once, not as an aspiration")
    }

    @Test("Compliant geometry is left alone")
    func alreadyCompliant() throws {
        let subject = CirclePrimitive(center: IconPoint(x: 8, y: 5), radius: 2)
        let constraint = Constraint.centered(
            CenteredConstraint(primitiveID: subject.id, axis: .horizontal))

        let resolved = ConstraintSolver.snapIntoCompliance(
            constraint,
            primitives: [.circle(subject)],
            existing: [],
            context: context)

        #expect(resolved == [.circle(subject)])
    }
}
