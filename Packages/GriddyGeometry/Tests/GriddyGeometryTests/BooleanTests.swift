//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
@testable import GriddyGeometry

private func approximately(_ value: Double,
                           _ expected: Double,
                           tolerance: Double = 1e-6) -> Bool {
    abs(value - expected) <= tolerance
}

/// An axis-aligned rectangle as a counterclockwise contour.
private func rectangle(x: Double, y: Double,
                       width: Double, height: Double) -> OutlinePath {
    let corners = [
        IconPoint(x: x, y: y),
        IconPoint(x: x + width, y: y),
        IconPoint(x: x + width, y: y + height),
        IconPoint(x: x, y: y + height)
    ]
    let segments = corners.indices.map { index in
        OutlineSegment.line(from: corners[index], to: corners[(index + 1) % 4])
    }
    return OutlinePath(contours: [OutlineContour(segments: segments)])
}

private func disc(x: Double, y: Double, radius: Double) -> OutlinePath {
    Outliner.outlineDisc(center: IconPoint(x: x, y: y), radius: radius)
}

@Suite("Segment intersection")
struct SegmentIntersectionTests {

    @Test("Crossing lines meet at one point")
    func lineLine() throws {
        let horizontal = OutlineSegment.line(from: IconPoint(x: 0, y: 5),
                                             to: IconPoint(x: 10, y: 5))
        let vertical = OutlineSegment.line(from: IconPoint(x: 4, y: 0),
                                           to: IconPoint(x: 4, y: 10))

        let crossings = SegmentIntersection.crossings(horizontal, vertical)
        #expect(crossings.count == 1)

        let crossing = try #require(crossings.first)
        #expect(approximately(crossing.point.x, 4))
        #expect(approximately(crossing.point.y, 5))
        #expect(approximately(crossing.t, 0.4))
        #expect(approximately(crossing.u, 0.5))
    }

    @Test("Parallel lines never meet")
    func parallelLines() {
        let first = OutlineSegment.line(from: .zero, to: IconPoint(x: 10, y: 0))
        let second = OutlineSegment.line(from: IconPoint(x: 0, y: 3),
                                         to: IconPoint(x: 10, y: 3))
        #expect(SegmentIntersection.crossings(first, second).isEmpty)
    }

    @Test("Segments that would cross if extended do not count")
    func nonOverlappingSpans() {
        let short = OutlineSegment.line(from: .zero, to: IconPoint(x: 2, y: 0))
        let far = OutlineSegment.line(from: IconPoint(x: 8, y: -5),
                                      to: IconPoint(x: 8, y: 5))
        #expect(SegmentIntersection.crossings(short, far).isEmpty)
    }

    @Test("A line through a circle meets it twice")
    func lineThroughCircle() {
        let line = OutlineSegment.line(from: IconPoint(x: -10, y: 0),
                                       to: IconPoint(x: 10, y: 0))
        let circle = OutlineSegment.arc(
            ArcSegment(center: .zero, radius: 3, startAngle: .zero, endAngle: .zero))

        let crossings = SegmentIntersection.crossings(line, circle)
        #expect(crossings.count == 2)

        let xs = crossings.map(\.point.x).sorted()
        #expect(approximately(xs[0], -3))
        #expect(approximately(xs[1], 3))
    }

    @Test("A line tangent to a circle meets it once")
    func tangentLine() {
        let line = OutlineSegment.line(from: IconPoint(x: -10, y: 3),
                                       to: IconPoint(x: 10, y: 3))
        let circle = OutlineSegment.arc(
            ArcSegment(center: .zero, radius: 3, startAngle: .zero, endAngle: .zero))

        let crossings = SegmentIntersection.crossings(line, circle)
        #expect(crossings.count == 1, "a tangency is one point, not two")
        #expect(approximately(crossings[0].point.y, 3))
    }

    @Test("A line missing a circle meets it nowhere")
    func missingLine() {
        let line = OutlineSegment.line(from: IconPoint(x: -10, y: 5),
                                       to: IconPoint(x: 10, y: 5))
        let circle = OutlineSegment.arc(
            ArcSegment(center: .zero, radius: 3, startAngle: .zero, endAngle: .zero))
        #expect(SegmentIntersection.crossings(line, circle).isEmpty)
    }

    @Test("A line crossing only part of an arc respects the sweep")
    func lineAgainstPartialArc() {
        // Upper half only: the crossing at y = 0, x = -3 is on the boundary,
        // the one at x = 3 likewise, but a horizontal line above centre should
        // meet the upper arc twice.
        let arc = OutlineSegment.arc(
            ArcSegment(center: .zero, radius: 3,
                       startAngle: .zero, endAngle: IconAngle(degrees: 180)))
        let line = OutlineSegment.line(from: IconPoint(x: -10, y: 1.5),
                                       to: IconPoint(x: 10, y: 1.5))

        #expect(SegmentIntersection.crossings(line, arc).count == 2)

        // Below centre the upper arc is not there at all.
        let below = OutlineSegment.line(from: IconPoint(x: -10, y: -1.5),
                                        to: IconPoint(x: 10, y: -1.5))
        #expect(SegmentIntersection.crossings(below, arc).isEmpty)
    }

    @Test("Overlapping circles meet at two points")
    func circleCircle() {
        let first = OutlineSegment.arc(
            ArcSegment(center: .zero, radius: 5, startAngle: .zero, endAngle: .zero))
        let second = OutlineSegment.arc(
            ArcSegment(center: IconPoint(x: 6, y: 0), radius: 5,
                       startAngle: .zero, endAngle: .zero))

        let crossings = SegmentIntersection.crossings(first, second)
        #expect(crossings.count == 2)

        // Both lie on the radical line x = 3, at y = +/-4.
        for crossing in crossings {
            #expect(approximately(crossing.point.x, 3))
            #expect(approximately(abs(crossing.point.y), 4))
        }
    }

    @Test("Externally tangent circles meet once")
    func tangentCircles() {
        let first = OutlineSegment.arc(
            ArcSegment(center: .zero, radius: 3, startAngle: .zero, endAngle: .zero))
        let second = OutlineSegment.arc(
            ArcSegment(center: IconPoint(x: 6, y: 0), radius: 3,
                       startAngle: .zero, endAngle: .zero))

        let crossings = SegmentIntersection.crossings(first, second)
        #expect(crossings.count == 1)
        #expect(approximately(crossings[0].point.x, 3))
    }

    @Test("Separated and nested circles never meet")
    func nonIntersectingCircles() {
        let unit = ArcSegment(center: .zero, radius: 1,
                              startAngle: .zero, endAngle: .zero)

        let far = OutlineSegment.arc(
            ArcSegment(center: IconPoint(x: 20, y: 0), radius: 1,
                       startAngle: .zero, endAngle: .zero))
        #expect(SegmentIntersection.crossings(.arc(unit), far).isEmpty)

        let enclosing = OutlineSegment.arc(
            ArcSegment(center: .zero, radius: 5, startAngle: .zero, endAngle: .zero))
        #expect(SegmentIntersection.crossings(.arc(unit), enclosing).isEmpty,
                "concentric circles never cross")
    }
}

@Suite("Point containment")
struct PointContainmentTests {

    @Test("A point inside a rectangle is contained")
    func insideRectangle() {
        let rect = rectangle(x: 0, y: 0, width: 10, height: 10)
        #expect(PointContainment.contains(rect, IconPoint(x: 5, y: 5)))
        #expect(!PointContainment.contains(rect, IconPoint(x: 15, y: 5)))
        #expect(!PointContainment.contains(rect, IconPoint(x: -5, y: 5)))
        #expect(!PointContainment.contains(rect, IconPoint(x: 5, y: 15)))
    }

    @Test("A point inside a disc is contained")
    func insideDisc() {
        let circle = disc(x: 0, y: 0, radius: 5)
        #expect(PointContainment.contains(circle, .zero))
        #expect(PointContainment.contains(circle, IconPoint(x: 4.9, y: 0)))
        #expect(!PointContainment.contains(circle, IconPoint(x: 5.1, y: 0)))
        #expect(!PointContainment.contains(circle, IconPoint(x: 0, y: 6)))
    }

    @Test("A ring's hole is outside, by winding number")
    func ringHole() {
        // The whole reason for winding rather than parity: a ray to a point in
        // the hole crosses two contours, which parity would call inside.
        let ring = Outliner.outlineRing(center: .zero, radius: 5, width: 2)

        #expect(!PointContainment.contains(ring, .zero), "the hole is not filled")
        #expect(PointContainment.contains(ring, IconPoint(x: 5, y: 0)),
                "the stroke band is filled")
        #expect(!PointContainment.contains(ring, IconPoint(x: 8, y: 0)),
                "outside the ring")
    }

    @Test("Winding number carries the sign of the orientation")
    func windingSign() {
        let counterclockwise = rectangle(x: 0, y: 0, width: 10, height: 10)
        let clockwise = OutlinePath(
            contours: counterclockwise.contours.map(\.reversed))

        #expect(PointContainment.windingNumber(of: counterclockwise,
                                               around: IconPoint(x: 5, y: 5)) == 1)
        #expect(PointContainment.windingNumber(of: clockwise,
                                               around: IconPoint(x: 5, y: 5)) == -1)
    }

    @Test("A point level with a vertex is counted once")
    func vertexOnRay() {
        // A ray passing exactly through a shared vertex must not double count,
        // or the point flips to outside.
        let rect = rectangle(x: 2, y: 2, width: 6, height: 6)
        #expect(PointContainment.contains(rect, IconPoint(x: 5, y: 2 + 1e-12)))
        #expect(PointContainment.contains(rect, IconPoint(x: 0.5, y: 5)) == false)
    }
}

@Suite("Boolean union")
struct UnionTests {

    @Test("Overlapping squares union to their combined area")
    func overlappingSquares() {
        let first = rectangle(x: 0, y: 0, width: 10, height: 10)
        let second = rectangle(x: 5, y: 0, width: 10, height: 10)

        let result = BooleanSolver.combine(first, second, operation: .union)

        // 100 + 100 - 50 overlap.
        #expect(approximately(result.area, 150))
        #expect(result.contours.count == 1, "a single merged region")
    }

    @Test("Disjoint shapes union to two separate contours")
    func disjointShapes() {
        let first = rectangle(x: 0, y: 0, width: 4, height: 4)
        let second = rectangle(x: 20, y: 20, width: 4, height: 4)

        let result = BooleanSolver.combine(first, second, operation: .union)

        #expect(approximately(result.area, 32))
        #expect(result.contours.count == 2)
    }

    @Test("Overlapping discs union to the lens-corrected area")
    func overlappingDiscs() {
        // Two unit-radius circles at distance 1 apart. The lens area is
        // 2 r^2 acos(d / 2r) - (d / 2) sqrt(4 r^2 - d^2).
        let radius = 5.0
        let distance = 6.0
        let first = disc(x: 0, y: 0, radius: radius)
        let second = disc(x: distance, y: 0, radius: radius)

        let lens = 2 * radius * radius * acos(distance / (2 * radius))
            - (distance / 2) * (4 * radius * radius - distance * distance).squareRoot()
        let expected = 2 * .pi * radius * radius - lens

        let result = BooleanSolver.combine(first, second, operation: .union)
        #expect(approximately(result.area, expected, tolerance: 1e-6))
    }

    @Test("A shape unioned with one it contains is unchanged")
    func containedShape() {
        let outer = rectangle(x: 0, y: 0, width: 10, height: 10)
        let inner = rectangle(x: 3, y: 3, width: 2, height: 2)

        let result = BooleanSolver.combine(outer, inner, operation: .union)
        #expect(approximately(result.area, 100))
    }

    @Test("Union with an empty path returns the other operand")
    func emptyOperand() {
        let rect = rectangle(x: 0, y: 0, width: 4, height: 4)

        #expect(approximately(
            BooleanSolver.combine(rect, .empty, operation: .union).area, 16))
        #expect(approximately(
            BooleanSolver.combine(.empty, rect, operation: .union).area, 16))
    }

    @Test("Unioning many shapes accumulates correctly")
    func multiUnion() {
        let strip = (0..<4).map { index in
            rectangle(x: Double(index) * 5, y: 0, width: 10, height: 10)
        }
        // Spans x from 0 to 25, all overlapping into one band.
        let result = BooleanSolver.union(strip)
        #expect(approximately(result.area, 250))
    }
}

@Suite("Boolean intersect")
struct IntersectTests {

    @Test("Overlapping squares intersect to their shared region")
    func overlappingSquares() {
        let first = rectangle(x: 0, y: 0, width: 10, height: 10)
        let second = rectangle(x: 5, y: 0, width: 10, height: 10)

        let result = BooleanSolver.combine(first, second, operation: .intersect)
        #expect(approximately(result.area, 50))
    }

    @Test("Disjoint shapes intersect to nothing")
    func disjointShapes() {
        let first = rectangle(x: 0, y: 0, width: 4, height: 4)
        let second = rectangle(x: 20, y: 20, width: 4, height: 4)

        let result = BooleanSolver.combine(first, second, operation: .intersect)
        #expect(result.isEmpty)
    }

    @Test("Overlapping discs intersect to the lens")
    func overlappingDiscs() {
        let radius = 5.0
        let distance = 6.0
        let lens = 2 * radius * radius * acos(distance / (2 * radius))
            - (distance / 2) * (4 * radius * radius - distance * distance).squareRoot()

        let result = BooleanSolver.combine(disc(x: 0, y: 0, radius: radius),
                                           disc(x: distance, y: 0, radius: radius),
                                           operation: .intersect)
        #expect(approximately(result.area, lens, tolerance: 1e-6))
    }

    @Test("Intersecting with an empty path gives nothing")
    func emptyOperand() {
        let rect = rectangle(x: 0, y: 0, width: 4, height: 4)
        #expect(BooleanSolver.combine(rect, .empty, operation: .intersect).isEmpty)
    }
}

@Suite("Boolean subtract")
struct SubtractTests {

    @Test("Subtracting an overlapping square leaves the remainder")
    func overlappingSquares() {
        let first = rectangle(x: 0, y: 0, width: 10, height: 10)
        let second = rectangle(x: 5, y: 0, width: 10, height: 10)

        let result = BooleanSolver.combine(first, second, operation: .subtract)
        #expect(approximately(result.area, 50))
    }

    @Test("Subtracting a disjoint shape changes nothing")
    func disjointShapes() {
        let first = rectangle(x: 0, y: 0, width: 4, height: 4)
        let second = rectangle(x: 20, y: 20, width: 4, height: 4)

        let result = BooleanSolver.combine(first, second, operation: .subtract)
        #expect(approximately(result.area, 16))
    }

    @Test("Subtracting a disc punches a hole")
    func punchedHole() {
        let plate = rectangle(x: 0, y: 0, width: 20, height: 20)
        let hole = disc(x: 10, y: 10, radius: 4)

        let result = BooleanSolver.combine(plate, hole, operation: .subtract)

        #expect(approximately(result.area, 400 - .pi * 16, tolerance: 1e-6))
        #expect(result.contours.count == 2, "an outer boundary and a hole")

        // The hole must run the other way, or it would add area instead of
        // removing it.
        let holeContour = result.contours.first { !$0.isCounterclockwise }
        #expect(holeContour != nil)
        #expect(!PointContainment.contains(result, IconPoint(x: 10, y: 10)),
                "the punched region is not filled")
    }

    @Test("Subtracting a covering shape leaves nothing")
    func fullyCovered() {
        let small = rectangle(x: 3, y: 3, width: 2, height: 2)
        let large = rectangle(x: 0, y: 0, width: 10, height: 10)

        let result = BooleanSolver.combine(small, large, operation: .subtract)
        #expect(result.isEmpty)
    }

    @Test("Subtracting from an empty path gives nothing")
    func emptyOperand() {
        let rect = rectangle(x: 0, y: 0, width: 4, height: 4)
        #expect(BooleanSolver.combine(.empty, rect, operation: .subtract).isEmpty)
        #expect(approximately(
            BooleanSolver.combine(rect, .empty, operation: .subtract).area, 16))
    }
}

@Suite("Booleans on real outlines")
struct OutlineBooleanTests {

    @Test("A magnifier's ring and handle union into one region")
    func magnifier() throws {
        // The shape from the mockup: a stroked circle crossed by a stroked
        // handle. The handle overlaps the ring, so the union is less than the
        // sum of the parts.
        let ring = Outliner.outlineRing(center: IconPoint(x: 8, y: 9),
                                        radius: 3.5,
                                        width: 1.2)
        let handle = Outliner.outlineSegment(from: IconPoint(x: 10.5, y: 6.5),
                                             to: IconPoint(x: 13, y: 4),
                                             width: 1.2,
                                             cap: .round)

        let result = BooleanSolver.combine(ring, handle, operation: .union)

        #expect(!result.isEmpty)
        #expect(result.area < ring.area + handle.area,
                "overlap should not be counted twice")
        #expect(result.area > ring.area, "the handle adds area")

        for contour in result.contours {
            #expect(contour.isConnected(tolerance: 1e-6),
                    "the solver produced an unclosed contour")
        }
    }

    @Test("Union of two stroked shapes keeps the ring's hole")
    func holePreserved() {
        let ring = Outliner.outlineRing(center: .zero, radius: 5, width: 1)
        // A bar well outside the ring, so the hole is untouched.
        let bar = Outliner.outlineSegment(from: IconPoint(x: 20, y: 0),
                                          to: IconPoint(x: 30, y: 0),
                                          width: 1,
                                          cap: .butt)

        let result = BooleanSolver.combine(ring, bar, operation: .union)
        #expect(!PointContainment.contains(result, .zero),
                "the ring's hole must survive the union")
    }

    @Test("Results contain only lines and arcs, never flattened curves")
    func staysAnalytic() {
        let first = disc(x: 0, y: 0, radius: 5)
        let second = disc(x: 6, y: 0, radius: 5)
        let result = BooleanSolver.combine(first, second, operation: .union)

        // Two circles crossing produce two arc pieces, not a polygon.
        #expect(result.segmentCount <= 4,
                "expected a handful of arcs, got \(result.segmentCount) segments")

        for contour in result.contours {
            for segment in contour.segments {
                if case .line = segment {
                    Issue.record("A circle union should contain no line segments")
                }
            }
        }
    }
}
