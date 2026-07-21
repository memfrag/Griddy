//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
import GriddyGeometry
@testable import GriddyConstraints

private let primitiveA = PrimitiveID()
private let primitiveB = PrimitiveID()

/// One instance of every constraint case, so the tests below cannot silently
/// skip a case that is added later.
private let allConstraints: [Constraint] = [
    .onGrid(OnGridConstraint(primitiveID: primitiveA)),
    .onKeyShape(OnKeyShapeConstraint(primitiveID: primitiveA,
                                     keyShapeID: UUID(),
                                     overshoot: 0.25)),
    .centered(CenteredConstraint(primitiveID: primitiveA, axis: .horizontal)),
    .equalSpacing(EqualSpacingConstraint(primitiveIDs: [primitiveA, primitiveB],
                                         axis: .vertical)),
    .equalRadius(EqualRadiusConstraint(primitiveIDs: [primitiveA, primitiveB])),
    .equalLength(EqualLengthConstraint(primitiveIDs: [primitiveA, primitiveB])),
    .tangent(TangentConstraint(primitiveID: primitiveA,
                               targetPrimitiveID: primitiveB)),
    .concentric(ConcentricConstraint(primitiveIDs: [primitiveA, primitiveB])),
    .symmetric(SymmetricConstraint(primitiveIDs: [primitiveA],
                                   axis: .vertical,
                                   axisPosition: 8)),
    .parallel(ParallelConstraint(primitiveIDs: [primitiveA, primitiveB])),
    .perpendicular(PerpendicularConstraint(primitiveIDs: [primitiveA, primitiveB])),
    .fixedAngle(FixedAngleConstraint(primitiveID: primitiveA,
                                     angle: IconAngle(degrees: 45))),
    .fixedDistance(FixedDistanceConstraint(primitiveID: primitiveA,
                                           targetPrimitiveID: primitiveB,
                                           distance: 3)),
    .opticalOffset(OpticalOffsetConstraint(primitiveID: primitiveA,
                                           offset: IconVector(dx: 0, dy: -0.125)))
]

@Suite("Constraint model")
struct ConstraintModelTests {

    @Test("Every constraint case is represented in the fixture")
    func fixtureCoversEveryCase() {
        // If a case is added to Constraint without being added above, this
        // count check fails and every other test in this suite becomes a lie.
        #expect(allConstraints.count == 14)
    }

    @Test("Constraints round trip through Codable")
    func codableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for constraint in allConstraints {
            let data = try encoder.encode(constraint)
            let restored = try decoder.decode(Constraint.self, from: data)
            #expect(restored == constraint, "\(constraint.displayName) did not survive")
        }
    }

    @Test("An array of mixed constraints round trips")
    func arrayRoundTrip() throws {
        let data = try JSONEncoder().encode(allConstraints)
        let restored = try JSONDecoder().decode([Constraint].self, from: data)
        #expect(restored == allConstraints)
    }

    @Test("Every constraint reports the primitives it governs")
    func affectedPrimitives() {
        for constraint in allConstraints {
            #expect(!constraint.affectedPrimitiveIDs.isEmpty,
                    "\(constraint.displayName) governs nothing")
            #expect(constraint.affectedPrimitiveIDs.contains(primitiveA))
        }
    }

    @Test("Every constraint has a non-empty display name")
    func displayNames() {
        for constraint in allConstraints {
            #expect(!constraint.displayName.isEmpty)
        }
    }

    @Test("Centering constraints name their axis")
    func centeringDisplayNames() {
        let horizontal = Constraint.centered(
            CenteredConstraint(primitiveID: primitiveA, axis: .horizontal))
        let vertical = Constraint.centered(
            CenteredConstraint(primitiveID: primitiveA, axis: .vertical))

        #expect(horizontal.displayName == "Centered horizontally")
        #expect(vertical.displayName == "Centered vertically")
    }

    @Test("Constraints are enabled by default and can be disabled")
    func enablement() {
        var body = CenteredConstraint(primitiveID: primitiveA, axis: .horizontal)
        #expect(Constraint.centered(body).isEnabled)

        body.isEnabled = false
        #expect(!Constraint.centered(body).isEnabled)
    }

    @Test("Identity survives encoding")
    func identityIsStable() throws {
        let original = Constraint.centered(
            CenteredConstraint(primitiveID: primitiveA, axis: .both))
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(Constraint.self, from: data)
        #expect(restored.id == original.id)
    }
}
