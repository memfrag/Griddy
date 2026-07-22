//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
@testable import GriddyGeometry

@Suite("Arc sweep")
struct ArcSweepTests {

    private func arc(from start: Double,
                     to end: Double,
                     clockwise: Bool = false) -> ArcPrimitive {
        ArcPrimitive(center: .zero,
                     radius: 4,
                     startAngle: IconAngle(degrees: start),
                     endAngle: IconAngle(degrees: end),
                     isClockwise: clockwise)
    }

    @Test("Counterclockwise sweep is the forward angular distance")
    func counterclockwiseSweep() {
        #expect(abs(arc(from: 0, to: 90).sweep - .pi / 2) < 1e-12)
        #expect(abs(arc(from: 315, to: 45).sweep - .pi / 2) < 1e-12,
                "A sweep crossing zero must not go the long way round")
    }

    @Test("Clockwise sweep is the reverse angular distance")
    func clockwiseSweep() {
        #expect(abs(arc(from: 90, to: 0, clockwise: true).sweep - .pi / 2) < 1e-12)
    }

    @Test("Coincident start and end describe a full circle")
    func fullCircle() {
        // The alternative reading is an empty arc, which would make a 360
        // degree arc silently invisible.
        #expect(abs(arc(from: 0, to: 0).sweep - 2 * .pi) < 1e-12)
    }

    @Test("Angle containment respects the sweep")
    func containment() {
        let quarter = arc(from: 0, to: 90)
        #expect(quarter.contains(angle: IconAngle(degrees: 45)))
        #expect(quarter.contains(angle: IconAngle(degrees: 0)))
        #expect(quarter.contains(angle: IconAngle(degrees: 90)))
        #expect(!quarter.contains(angle: IconAngle(degrees: 91)))
        #expect(!quarter.contains(angle: IconAngle(degrees: 270)))
    }

    @Test("Angle containment works across the zero crossing")
    func containmentAcrossZero() {
        let crossing = arc(from: 315, to: 45)
        #expect(crossing.contains(angle: IconAngle(degrees: 0)))
        #expect(crossing.contains(angle: IconAngle(degrees: 350)))
        #expect(!crossing.contains(angle: IconAngle(degrees: 180)))
    }

    @Test("Endpoints sit on the radius at the sweep angles")
    func endpoints() {
        let quarter = arc(from: 0, to: 90)
        #expect(abs(quarter.startPoint.x - 4) < 1e-12)
        #expect(abs(quarter.startPoint.y) < 1e-12)
        #expect(abs(quarter.endPoint.x) < 1e-12)
        #expect(abs(quarter.endPoint.y - 4) < 1e-12)
    }
}

@Suite("Distance to primitives")
struct DistanceTests {

    @Test("Distance to a line segment clamps at the endpoints")
    func lineDistance() {
        let start = IconPoint(x: 0, y: 0)
        let end = IconPoint(x: 10, y: 0)

        // Perpendicular from the middle.
        #expect(PrimitiveGeometry.distance(from: IconPoint(x: 5, y: 3),
                                           toSegmentFrom: start, to: end) == 3)
        // Beyond the end: measured to the endpoint, not the infinite line.
        #expect(PrimitiveGeometry.distance(from: IconPoint(x: 14, y: 0),
                                           toSegmentFrom: start, to: end) == 4)
        // On the segment.
        #expect(PrimitiveGeometry.distance(from: IconPoint(x: 2, y: 0),
                                           toSegmentFrom: start, to: end) == 0)
    }

    @Test("A degenerate segment measures to its single point")
    func degenerateSegment() {
        let point = IconPoint(x: 3, y: 4)
        #expect(PrimitiveGeometry.distance(from: .zero,
                                           toSegmentFrom: point, to: point) == 5)
    }

    @Test("Distance to a circle is measured from its outline")
    func circleDistance() {
        let circle = IconPrimitive.circle(
            CirclePrimitive(center: IconPoint(x: 8, y: 8), radius: 4))

        // Outside.
        #expect(PrimitiveGeometry.distance(from: IconPoint(x: 14, y: 8),
                                           to: circle) == 2)
        // Inside: the centre is a full radius from the outline, not zero.
        #expect(PrimitiveGeometry.distance(from: IconPoint(x: 8, y: 8),
                                           to: circle) == 4)
        // On it.
        #expect(PrimitiveGeometry.distance(from: IconPoint(x: 12, y: 8),
                                           to: circle) == 0)
    }

    @Test("Distance to an arc falls back to endpoints outside the sweep")
    func arcDistance() {
        let arc = IconPrimitive.arc(
            ArcPrimitive(center: .zero,
                         radius: 4,
                         startAngle: IconAngle(degrees: 0),
                         endAngle: IconAngle(degrees: 90)))

        // Within the sweep: radial distance.
        let radial = PrimitiveGeometry.distance(from: IconPoint(x: 6, y: 0), to: arc)
        #expect(radial.map { abs($0 - 2) < 1e-12 } == true)

        // Outside the sweep: the nearest endpoint wins. From (-4, 0) that is
        // the 90 degree endpoint at (0, 4), a distance of sqrt(32) -- not the
        // 0 degree endpoint at (4, 0), which is a full diameter away.
        let opposite = PrimitiveGeometry.distance(from: IconPoint(x: -4, y: 0),
                                                  to: arc)
        #expect(opposite.map { abs($0 - 32.squareRoot()) < 1e-12 } == true)
    }

    @Test("A point at an arc's centre is one radius from every part of it")
    func arcCentre() {
        let arc = IconPrimitive.arc(
            ArcPrimitive(center: IconPoint(x: 5, y: 5),
                         radius: 3,
                         startAngle: IconAngle(degrees: 0),
                         endAngle: IconAngle(degrees: 180)))
        #expect(PrimitiveGeometry.distance(from: IconPoint(x: 5, y: 5), to: arc) == 3)
    }

    @Test("Rounded rectangle signed distance is negative inside")
    func roundedRectSignedDistance() {
        let bounds = IconRect(x: 0, y: 0, width: 10, height: 10)

        let inside = PrimitiveGeometry.signedDistance(from: IconPoint(x: 5, y: 5),
                                                      toRoundedRect: bounds,
                                                      cornerRadius: 2)
        #expect(inside < 0)

        let outside = PrimitiveGeometry.signedDistance(from: IconPoint(x: 15, y: 5),
                                                       toRoundedRect: bounds,
                                                       cornerRadius: 2)
        #expect(abs(outside - 5) < 1e-12)

        let onEdge = PrimitiveGeometry.signedDistance(from: IconPoint(x: 10, y: 5),
                                                      toRoundedRect: bounds,
                                                      cornerRadius: 2)
        #expect(abs(onEdge) < 1e-12)
    }

    @Test("A zero corner radius behaves as a plain rectangle")
    func squareCorners() {
        let bounds = IconRect(x: 0, y: 0, width: 10, height: 10)
        let corner = PrimitiveGeometry.signedDistance(from: IconPoint(x: 10, y: 10),
                                                      toRoundedRect: bounds,
                                                      cornerRadius: 0)
        #expect(abs(corner) < 1e-12, "The corner point lies exactly on the outline")
    }

    @Test("Compounds and imported paths report no measurable centerline")
    func unmeasurable() {
        let compound = IconPrimitive.compound(
            CompoundPrimitive(operation: .union, children: []))
        let imported = IconPrimitive.importedPath(
            ImportedPathPrimitive(pathData: "M0 0 L10 10"))

        #expect(PrimitiveGeometry.distance(from: .zero, to: compound) == nil)
        #expect(PrimitiveGeometry.distance(from: .zero, to: imported) == nil)
    }
}

@Suite("Bounds")
struct BoundsTests {

    @Test("Arc bounds include cardinal points inside the sweep")
    func arcBoundsIncludeExtremes() throws {
        // A half circle from 0 to 180 passes through 90 degrees, so its top is
        // at the radius, not at the higher of the two endpoints (both y = 0).
        let arc = IconPrimitive.arc(
            ArcPrimitive(center: .zero,
                         radius: 4,
                         startAngle: IconAngle(degrees: 0),
                         endAngle: IconAngle(degrees: 180)))

        let bounds = try #require(PrimitiveGeometry.bounds(of: arc))
        #expect(abs(bounds.maxY - 4) < 1e-12)
        #expect(abs(bounds.minY) < 1e-12)
        #expect(abs(bounds.minX + 4) < 1e-12)
        #expect(abs(bounds.maxX - 4) < 1e-12)
    }

    @Test("A shallow arc is not overstated")
    func shallowArcBounds() throws {
        let arc = IconPrimitive.arc(
            ArcPrimitive(center: .zero,
                         radius: 4,
                         startAngle: IconAngle(degrees: 0),
                         endAngle: IconAngle(degrees: 45)))

        let bounds = try #require(PrimitiveGeometry.bounds(of: arc))
        #expect(bounds.maxY < 4, "No cardinal point lies inside a 0-45 sweep")
    }

    @Test("Circle bounds are the full diameter")
    func circleBounds() throws {
        let circle = IconPrimitive.circle(
            CirclePrimitive(center: IconPoint(x: 8, y: 8), radius: 3))
        let bounds = try #require(PrimitiveGeometry.bounds(of: circle))

        #expect(bounds.size.width == 6)
        #expect(bounds.size.height == 6)
        #expect(bounds.center == IconPoint(x: 8, y: 8))
    }

    @Test("Bounds of an empty point list are nil rather than zero")
    func emptyBounds() {
        #expect(PrimitiveGeometry.bounds(containing: []) == nil)
    }
}

@Suite("Hit testing")
struct HitTestingTests {

    private let circle = IconPrimitive.circle(
        CirclePrimitive(center: IconPoint(x: 8, y: 8), radius: 4))

    @Test("A point within tolerance of the centerline hits")
    func hitsWithinTolerance() {
        #expect(HitTesting.hit(circle, at: IconPoint(x: 12.2, y: 8), tolerance: 0.3))
        #expect(!HitTesting.hit(circle, at: IconPoint(x: 12.6, y: 8), tolerance: 0.3))
    }

    @Test("The interior of an unfilled circle does not hit")
    func interiorMisses() {
        // Griddy draws centerlines, so the inside of a circle is empty space.
        #expect(!HitTesting.hit(circle, at: IconPoint(x: 8, y: 8), tolerance: 0.3))
    }

    @Test("Topmost picks the last matching primitive in draw order")
    func topmostWins() throws {
        let lower = CirclePrimitive(center: IconPoint(x: 8, y: 8), radius: 4)
        let upper = CirclePrimitive(center: IconPoint(x: 8, y: 8), radius: 4)
        let stack: [IconPrimitive] = [.circle(lower), .circle(upper)]

        let picked = try #require(HitTesting.topmost(in: stack,
                                                     at: IconPoint(x: 12, y: 8),
                                                     tolerance: 0.3))
        #expect(picked.id == upper.id, "Later in draw order means visually on top")
    }

    @Test("Hidden primitives are not selectable")
    func hiddenIsNotHit() {
        var hidden = CirclePrimitive(center: IconPoint(x: 8, y: 8), radius: 4)
        hidden.attributes.isVisible = false

        #expect(HitTesting.topmost(in: [.circle(hidden)],
                                   at: IconPoint(x: 12, y: 8),
                                   tolerance: 0.3) == nil)
    }

    @Test("Imported paths fall back to their bounds so they stay selectable")
    func importedFallsBackToBounds() {
        let imported = IconPrimitive.importedPath(
            ImportedPathPrimitive(pathData: "M0 0"))
        // No semantic geometry and no bounds either, so nothing to hit.
        #expect(!HitTesting.hit(imported, at: .zero, tolerance: 1))
    }

    @Test("Marquee selection uses bounds intersection")
    func marquee() {
        let inside = IconPrimitive.circle(
            CirclePrimitive(center: IconPoint(x: 4, y: 4), radius: 1))
        let outside = IconPrimitive.circle(
            CirclePrimitive(center: IconPoint(x: 20, y: 20), radius: 1))

        let picked = HitTesting.primitives(in: [inside, outside],
                                           intersecting: IconRect(x: 0, y: 0,
                                                                  width: 10, height: 10))
        #expect(picked.count == 1)
        #expect(picked.first?.id == inside.id)
    }
}

@Suite("Translation")
struct TranslationTests {

    private let move = IconVector(dx: 3, dy: -2)

    @Test("Translation preserves identity and attributes")
    func preservesIdentity() {
        let circle = CirclePrimitive(center: IconPoint(x: 5, y: 5), radius: 2)
        let moved = IconPrimitive.circle(circle).translated(by: move)

        #expect(moved.id == circle.id, "Identity must survive edits")
        #expect(moved.attributes == circle.attributes)
    }

    @Test("Every measurable primitive shifts by exactly the vector")
    func boundsShift() throws {
        let primitives: [IconPrimitive] = [
            .line(LinePrimitive(start: .zero, end: IconPoint(x: 4, y: 4))),
            .circle(CirclePrimitive(center: IconPoint(x: 5, y: 5), radius: 2)),
            .arc(ArcPrimitive(center: IconPoint(x: 5, y: 5),
                              radius: 2,
                              startAngle: IconAngle(degrees: 0),
                              endAngle: IconAngle(degrees: 90))),
            .roundedRect(RoundedRectPrimitive(
                bounds: IconRect(x: 1, y: 1, width: 4, height: 3), cornerRadius: 1)),
            .capsule(CapsulePrimitive(
                bounds: IconRect(x: 1, y: 1, width: 6, height: 2))),
            .polyline(PolylinePrimitive(points: [.zero, IconPoint(x: 2, y: 2)]))
        ]

        for primitive in primitives {
            let before = try #require(PrimitiveGeometry.bounds(of: primitive))
            let after = try #require(
                PrimitiveGeometry.bounds(of: primitive.translated(by: move)))

            #expect(abs(after.minX - (before.minX + move.dx)) < 1e-12,
                    "\(primitive.kindName) did not shift in x")
            #expect(abs(after.minY - (before.minY + move.dy)) < 1e-12,
                    "\(primitive.kindName) did not shift in y")
            #expect(abs(after.size.width - before.size.width) < 1e-12,
                    "\(primitive.kindName) changed size when moved")
        }
    }

    @Test("A symmetric path carries its mirror axis along")
    func symmetricPathCarriesAxis() {
        let path = SymmetricPathPrimitive(points: [IconPoint(x: 2, y: 0),
                                                   IconPoint(x: 4, y: 4)],
                                          axis: .vertical,
                                          axisPosition: 8)

        guard case .symmetricPath(let moved) =
                IconPrimitive.symmetricPath(path).translated(by: move) else {
            Issue.record("Expected a symmetric path")
            return
        }

        #expect(moved.axisPosition == 11, "Axis must travel with the geometry")

        // If the axis stayed put, the mirrored half would move the wrong way and
        // the shape would deform rather than translate.
        let originalWidth = PrimitiveGeometry.bounds(
            containing: path.points + path.mirroredPoints)?.size.width
        let movedWidth = PrimitiveGeometry.bounds(
            containing: moved.points + moved.mirroredPoints)?.size.width
        #expect(originalWidth == movedWidth)
    }
}
