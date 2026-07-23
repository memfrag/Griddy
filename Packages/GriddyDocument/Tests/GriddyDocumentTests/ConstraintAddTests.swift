//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
import GriddyGeometry
import GriddyConstraints
@testable import GriddyDocument

private let metrics = TemplateMetrics(baselineY: 100, caplineY: 36,
                                      leftMarginX: 20, rightMarginX: 116,
                                      alignmentRects: [:])

/// The newly-enforced constraints snap geometry the moment they are added, the
/// same as every other enforced kind. Verifying through `addConstraint` covers
/// the whole path: conflict check, snap, and append.
@Suite("Adding enforced constraints")
struct ConstraintAddTests {

    private func document(_ primitives: [IconPrimitive]) -> SymbolDocument {
        var document = SymbolDocument.new(name: "T",
                                          templateMetrics: metrics,
                                          appVersion: "test")
        for primitive in primitives {
            document.addPrimitive(primitive)
        }
        return document
    }

    @Test("Fixed distance snaps on add")
    func fixedDistanceSnaps() throws {
        let a = CirclePrimitive(center: IconPoint(x: 0, y: 0), radius: 1)
        let b = CirclePrimitive(center: IconPoint(x: 2, y: 0), radius: 1)
        var doc = document([.circle(a), .circle(b)])

        try doc.addConstraint(.fixedDistance(FixedDistanceConstraint(
            primitiveID: b.id, targetPrimitiveID: a.id, distance: 6)))

        // b is repositioned to satisfy the distance without being dragged.
        let moved = try #require(doc.primitive(withID: b.id)?.anchor)
        let anchor = try #require(doc.primitive(withID: a.id)?.anchor)
        #expect(abs(anchor.distance(to: moved) - 6) < 1e-9)
    }

    @Test("On key shape snaps a circle to the key shape on add")
    func onKeyShapeSnaps() throws {
        let circle = CirclePrimitive(center: IconPoint(x: 0, y: 0), radius: 1)
        var doc = document([.circle(circle)])
        let keyShape = try #require(doc.keyShapes.all.first)

        try doc.addConstraint(.onKeyShape(OnKeyShapeConstraint(
            primitiveID: circle.id, keyShapeID: keyShape.id, overshoot: 0)))

        let anchor = try #require(doc.primitive(withID: circle.id)?.anchor)
        #expect(anchor == keyShape.bounds.center)
    }

    @Test("Equal spacing distributes on add")
    func equalSpacingSnaps() throws {
        let a = CirclePrimitive(center: IconPoint(x: 0, y: 0), radius: 1)
        let b = CirclePrimitive(center: IconPoint(x: 1, y: 0), radius: 1)
        let c = CirclePrimitive(center: IconPoint(x: 10, y: 0), radius: 1)
        var doc = document([.circle(a), .circle(b), .circle(c)])

        try doc.addConstraint(.equalSpacing(EqualSpacingConstraint(
            primitiveIDs: [a.id, b.id, c.id], axis: .horizontal)))

        let middle = try #require(doc.primitive(withID: b.id)?.anchor)
        #expect(abs(middle.x - 5) < 1e-9)
    }
}
