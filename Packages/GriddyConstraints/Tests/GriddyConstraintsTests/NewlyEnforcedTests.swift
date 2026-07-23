//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
import GriddyGeometry
@testable import GriddyConstraints

private let canvas = IconRect(x: 0, y: 0, width: 16, height: 16)

private func line(_ id: PrimitiveID, from: IconPoint, to: IconPoint) -> IconPrimitive {
    .line(LinePrimitive(id: id, start: from, end: to))
}

private func circle(_ id: PrimitiveID, at centre: IconPoint, r: Double) -> IconPrimitive {
    .circle(CirclePrimitive(id: id, center: centre, radius: r))
}

private func resolve(_ primitives: [IconPrimitive],
                     _ constraints: [Constraint],
                     context: ConstraintContext = ConstraintContext(capHeightBox: canvas),
                     pinned: Set<PrimitiveID> = []) -> [PrimitiveID: IconPrimitive] {
    let result = ConstraintSolver.resolve(primitives: primitives,
                                          constraints: constraints,
                                          context: context, pinned: pinned)
    return Dictionary(uniqueKeysWithValues: result.map { ($0.id, $0) })
}

@Suite("Fixed distance")
struct FixedDistanceTests {

    @Test("The unpinned primitive moves to the declared distance")
    func movesToDistance() {
        let a = PrimitiveID(), b = PrimitiveID()
        let out = resolve(
            [circle(a, at: IconPoint(x: 0, y: 0), r: 1),
             circle(b, at: IconPoint(x: 3, y: 0), r: 1)],
            [.fixedDistance(FixedDistanceConstraint(
                primitiveID: b, targetPrimitiveID: a, distance: 5))],
            pinned: [a])

        // b slides along the a-b line until it is 5 from a.
        #expect(out[b]?.anchor?.x == 5)
        #expect(out[b]?.anchor?.y == 0)
        #expect(out[a]?.anchor?.x == 0, "the pinned primitive does not move")
    }

    @Test("Holding the primitive that would move moves the other instead")
    func movesTheOtherWhenPinned() {
        let a = PrimitiveID(), b = PrimitiveID()
        let out = resolve(
            [circle(a, at: IconPoint(x: 0, y: 0), r: 1),
             circle(b, at: IconPoint(x: 3, y: 0), r: 1)],
            [.fixedDistance(FixedDistanceConstraint(
                primitiveID: b, targetPrimitiveID: a, distance: 5))],
            pinned: [b])

        // The user holds b, so a moves to sit 5 away from it instead.
        let distance = out[a]!.anchor!.distance(to: out[b]!.anchor!)
        #expect(abs(distance - 5) < 1e-9)
        #expect(out[b]?.anchor?.x == 3, "the held primitive stays")
    }
}

@Suite("Equal length")
struct EqualLengthTests {

    @Test("Lines are brought to a shared length")
    func sharesLength() {
        let a = PrimitiveID(), b = PrimitiveID()
        let out = resolve(
            [line(a, from: IconPoint(x: 0, y: 0), to: IconPoint(x: 4, y: 0)),
             line(b, from: IconPoint(x: 0, y: 5), to: IconPoint(x: 10, y: 5))],
            [.equalLength(EqualLengthConstraint(primitiveIDs: [a, b]))],
            pinned: [a])

        // b takes a's length of 4, rescaled about its own midpoint.
        #expect(abs((out[b]?.length ?? 0) - 4) < 1e-9)
        #expect(out[b]?.anchor?.x == 5, "rescaled about the midpoint")
    }
}

@Suite("Equal spacing")
struct EqualSpacingTests {

    @Test("Interior primitives are spread evenly between the extremes")
    func spreadsEvenly() {
        let a = PrimitiveID(), b = PrimitiveID(), c = PrimitiveID()
        let out = resolve(
            [circle(a, at: IconPoint(x: 0, y: 0), r: 1),
             circle(b, at: IconPoint(x: 1, y: 0), r: 1),
             circle(c, at: IconPoint(x: 9, y: 0), r: 1)],
            [.equalSpacing(EqualSpacingConstraint(
                primitiveIDs: [a, b, c], axis: .horizontal))])

        // The ends fix the span 0..9; the middle lands at 4.5.
        #expect(out[a]?.anchor?.x == 0)
        #expect(out[c]?.anchor?.x == 9)
        #expect(abs((out[b]?.anchor?.x ?? 0) - 4.5) < 1e-9)
    }

    @Test("Fewer than three primitives is left alone")
    func needsThree() {
        let a = PrimitiveID(), b = PrimitiveID()
        let out = resolve(
            [circle(a, at: IconPoint(x: 0, y: 0), r: 1),
             circle(b, at: IconPoint(x: 3, y: 0), r: 1)],
            [.equalSpacing(EqualSpacingConstraint(
                primitiveIDs: [a, b], axis: .horizontal))])
        #expect(out[b]?.anchor?.x == 3)
    }
}

@Suite("On key shape")
struct OnKeyShapeTests {

    @Test("A circle centres on the key shape and takes its size")
    func fitsCircle() {
        let key = UUID()
        let bounds = IconRect(x: 4, y: 4, width: 8, height: 8)
        let context = ConstraintContext(capHeightBox: canvas,
                                        keyShapeBounds: [key: bounds])

        let a = PrimitiveID()
        let out = resolve(
            [circle(a, at: IconPoint(x: 0, y: 0), r: 1)],
            [.onKeyShape(OnKeyShapeConstraint(
                primitiveID: a, keyShapeID: key, overshoot: 0.5))],
            context: context)

        #expect(out[a]?.anchor == bounds.center)
        // Half the smaller dimension (4) plus overshoot.
        #expect(abs((out[a]?.radius ?? 0) - 4.5) < 1e-9)
    }

    @Test("A missing key shape leaves the primitive untouched")
    func toleratesMissingKeyShape() {
        let a = PrimitiveID()
        let out = resolve(
            [circle(a, at: IconPoint(x: 2, y: 2), r: 1)],
            [.onKeyShape(OnKeyShapeConstraint(
                primitiveID: a, keyShapeID: UUID(), overshoot: 0))])
        #expect(out[a]?.anchor == IconPoint(x: 2, y: 2))
    }
}
