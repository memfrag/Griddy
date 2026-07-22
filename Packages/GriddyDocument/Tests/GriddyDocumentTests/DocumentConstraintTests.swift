//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
import GriddyGeometry
import GriddyConstraints
@testable import GriddyDocument

private func documentWithCircle(at point: IconPoint,
                                radius: Double = 2) -> (SymbolDocument, CirclePrimitive) {
    var document = SymbolDocument.new(name: "Test",
                                      templateMetrics: .blankTemplate,
                                      appVersion: "1.0.0")
    let circle = CirclePrimitive(center: point, radius: radius)
    document.addPrimitive(.circle(circle))
    return (document, circle)
}

private func approximately(_ value: Double,
                           _ expected: Double,
                           tolerance: Double = 1e-9) -> Bool {
    abs(value - expected) <= tolerance
}

@Suite("Document constraints")
struct DocumentConstraintTests {

    @Test("The context comes from the document's own coordinate system")
    func context() {
        let (document, _) = documentWithCircle(at: IconPoint(x: 4, y: 4))
        let context = document.constraintContext

        #expect(context.canvasBounds == document.coordinateSystem.canvasBounds)
        #expect(context.gridInterval == document.grid.secondaryInterval)
        #expect(context.keyShapeBounds.count == document.keyShapes.all.count)
    }

    @Test("Adding a constraint moves geometry into compliance")
    func addSnapsIntoCompliance() throws {
        var (document, circle) = documentWithCircle(at: IconPoint(x: 3, y: 5))

        try document.addConstraint(.centered(
            CenteredConstraint(primitiveID: circle.id, axis: .horizontal)))

        let anchor = try #require(document.primitive(withID: circle.id)?.anchor)
        #expect(approximately(anchor.x, 8), "snapped to the canvas centre line")
        #expect(document.constraints.count == 1)
    }

    @Test("A conflicting constraint is refused and nothing changes")
    func conflictRefused() throws {
        var (document, circle) = documentWithCircle(at: IconPoint(x: 3, y: 5))

        try document.addConstraint(.centered(
            CenteredConstraint(primitiveID: circle.id, axis: .horizontal)))
        let afterFirst = document

        #expect(throws: ConstraintRejected.self) {
            try document.addConstraint(.centered(
                CenteredConstraint(primitiveID: circle.id, axis: .horizontal)))
        }

        // A refusal must leave the document untouched, not half-applied.
        #expect(document == afterFirst)
    }

    @Test("The refusal names what it conflicts with")
    func conflictMessage() throws {
        var (document, circle) = documentWithCircle(at: IconPoint(x: 3, y: 5))
        let first = Constraint.centered(
            CenteredConstraint(primitiveID: circle.id, axis: .horizontal))
        try document.addConstraint(first)

        do {
            try document.addConstraint(.centered(
                CenteredConstraint(primitiveID: circle.id, axis: .both)))
            Issue.record("Expected the constraint to be refused")
        } catch let error as ConstraintRejected {
            #expect(!error.message.isEmpty)
            #expect(error.conflict.existing == first)
        }
    }

    @Test("Compatible constraints both apply")
    func compatibleConstraints() throws {
        var (document, circle) = documentWithCircle(at: IconPoint(x: 3, y: 5))

        try document.addConstraint(.centered(
            CenteredConstraint(primitiveID: circle.id, axis: .horizontal)))
        try document.addConstraint(.centered(
            CenteredConstraint(primitiveID: circle.id, axis: .vertical)))

        let anchor = try #require(document.primitive(withID: circle.id)?.anchor)
        #expect(approximately(anchor.x, 8))
        #expect(approximately(anchor.y, 8))
        #expect(document.constraints.count == 2)
    }

    @Test("Drag restriction reflects the constraints in force")
    func dragRestriction() throws {
        var (document, circle) = documentWithCircle(at: IconPoint(x: 3, y: 5))
        #expect(document.dragRestriction(for: circle.id) == .free)

        try document.addConstraint(.centered(
            CenteredConstraint(primitiveID: circle.id, axis: .horizontal)))

        let restriction = document.dragRestriction(for: circle.id)
        let moved = restriction.apply(to: IconVector(dx: 4, dy: 3))
        #expect(approximately(moved.dx, 0), "cannot be dragged off the centre line")
        #expect(approximately(moved.dy, 3))
    }

    @Test("Disabling a constraint releases the restriction but keeps the record")
    func disabling() throws {
        var (document, circle) = documentWithCircle(at: IconPoint(x: 3, y: 5))
        let constraint = Constraint.centered(
            CenteredConstraint(primitiveID: circle.id, axis: .horizontal))
        try document.addConstraint(constraint)

        document.setConstraint(constraint.id, enabled: false)

        #expect(document.constraints.count == 1, "the relationship is kept")
        #expect(document.dragRestriction(for: circle.id) == .free,
                "but it no longer restricts")
    }

    @Test("Removing a constraint drops it entirely")
    func removal() throws {
        var (document, circle) = documentWithCircle(at: IconPoint(x: 3, y: 5))
        let constraint = Constraint.centered(
            CenteredConstraint(primitiveID: circle.id, axis: .horizontal))
        try document.addConstraint(constraint)

        document.removeConstraint(withID: constraint.id)

        #expect(document.constraints.isEmpty)
        #expect(document.dragRestriction(for: circle.id) == .free)
    }

    @Test("Deleting a primitive also drops the constraints that governed it")
    func deletionDropsConstraints() throws {
        var (document, circle) = documentWithCircle(at: IconPoint(x: 3, y: 5))
        try document.addConstraint(.centered(
            CenteredConstraint(primitiveID: circle.id, axis: .horizontal)))

        document.removePrimitives(withIDs: [circle.id])

        #expect(document.constraints.isEmpty,
                "a constraint on absent geometry can never be satisfied")
    }

    @Test("Resolution respects the primitive being held")
    func pinnedDuringResolve() throws {
        var document = SymbolDocument.new(name: "Test",
                                          templateMetrics: .blankTemplate,
                                          appVersion: "1.0.0")
        let first = CirclePrimitive(center: IconPoint(x: 4, y: 4), radius: 2)
        let second = CirclePrimitive(center: IconPoint(x: 10, y: 10), radius: 2)
        document.addPrimitive(.circle(first))
        document.addPrimitive(.circle(second))

        try document.addConstraint(.concentric(
            ConcentricConstraint(primitiveIDs: [first.id, second.id])))

        // Move the second and hold it: the first should follow, not the reverse.
        document.translatePrimitives(withIDs: [second.id],
                                     by: IconVector(dx: 3, dy: 0))
        document.resolveConstraints(pinned: [second.id])

        let held = try #require(document.primitive(withID: second.id)?.anchor)
        let follower = try #require(document.primitive(withID: first.id)?.anchor)
        #expect(approximately(held.x, follower.x))
        #expect(approximately(held.y, follower.y))
    }

    @Test("Constraints survive a document round trip")
    func roundTrip() throws {
        var (document, circle) = documentWithCircle(at: IconPoint(x: 3, y: 5))
        try document.addConstraint(.centered(
            CenteredConstraint(primitiveID: circle.id, axis: .horizontal)))
        try document.addConstraint(.onGrid(
            OnGridConstraint(primitiveID: circle.id)))

        let wrapper = try SymbolDocumentPackage(document: document).fileWrapper()
        let restored = try SymbolDocumentPackage.read(from: wrapper).document

        #expect(restored.constraints == document.constraints)
        #expect(restored.dragRestriction(for: circle.id)
                == document.dragRestriction(for: circle.id))
    }
}
