//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
@testable import GriddyGeometry

/// Stroke widths spanning thin, ordinary, and thick enough to swallow a hole.
private let testWidths: [Double] = [0.1, 0.65, 1.2, 2.35, 4.0]

private func approximately(_ value: Double,
                           _ expected: Double,
                           tolerance: Double = 1e-9) -> Bool {
    abs(value - expected) <= tolerance
}

@Suite("Outline contour mechanics")
struct OutlineContourTests {

    @Test("A counterclockwise square has positive area")
    func squareArea() {
        let corners = [
            IconPoint(x: 0, y: 0), IconPoint(x: 4, y: 0),
            IconPoint(x: 4, y: 4), IconPoint(x: 0, y: 4)
        ]
        let contour = OutlineContour(segments: corners.indices.map { index in
            .line(from: corners[index], to: corners[(index + 1) % 4])
        })

        #expect(approximately(contour.signedArea, 16))
        #expect(contour.isCounterclockwise)
    }

    @Test("Reversing a contour flips its orientation but not its area")
    func reversal() {
        let corners = [
            IconPoint(x: 0, y: 0), IconPoint(x: 4, y: 0),
            IconPoint(x: 4, y: 4), IconPoint(x: 0, y: 4)
        ]
        let contour = OutlineContour(segments: corners.indices.map { index in
            .line(from: corners[index], to: corners[(index + 1) % 4])
        })
        let reversed = contour.reversed

        #expect(approximately(reversed.signedArea, -16))
        #expect(approximately(reversed.area, contour.area))
        #expect(reversed.isConnected())
    }

    @Test("A full circle contour has area pi r squared")
    func circleArea() {
        let contour = OutlineContour(segments: [
            .arc(ArcSegment(center: .zero, radius: 3,
                            startAngle: .zero, endAngle: .zero))
        ])
        #expect(approximately(contour.signedArea, .pi * 9))
    }

    @Test("A half disc accounts for the circular segment, not just the chord")
    func halfDiscArea() {
        // Chord alone would give zero area; the bulge is the whole shape.
        let contour = OutlineContour(segments: [
            .arc(ArcSegment(center: .zero, radius: 2,
                            startAngle: .zero,
                            endAngle: IconAngle(degrees: 180))),
            .line(from: IconPoint(x: -2, y: 0), to: IconPoint(x: 2, y: 0))
        ])
        #expect(approximately(contour.signedArea, .pi * 4 / 2))
    }
}

@Suite("Line outlining")
struct LineOutliningTests {

    private let start = IconPoint(x: 2, y: 5)
    private let end = IconPoint(x: 10, y: 5)
    private var length: Double { start.distance(to: end) }

    @Test("A round-capped segment is a rectangle plus a full disc")
    func roundCapArea() {
        for width in testWidths {
            let outline = Outliner.outlineSegment(from: start, to: end,
                                                  width: width, cap: .round)
            // Two half-disc caps make exactly one disc.
            let expected = width * length + .pi * (width / 2) * (width / 2)
            #expect(approximately(outline.area, expected, tolerance: 1e-9),
                    "width \(width)")
        }
    }

    @Test("A butt-capped segment is exactly the rectangle")
    func buttCapArea() {
        for width in testWidths {
            let outline = Outliner.outlineSegment(from: start, to: end,
                                                  width: width, cap: .butt)
            #expect(approximately(outline.area, width * length), "width \(width)")
        }
    }

    @Test("A square cap extends the segment by half a width at each end")
    func squareCapArea() {
        for width in testWidths {
            let outline = Outliner.outlineSegment(from: start, to: end,
                                                  width: width, cap: .square)
            #expect(approximately(outline.area, width * (length + width)),
                    "width \(width)")
        }
    }

    @Test("Outlines are counterclockwise and closed")
    func orientationAndClosure() {
        for cap in [LineCap.butt, .round, .square] {
            let outline = Outliner.outlineSegment(from: start, to: end,
                                                  width: 1.2, cap: cap)
            let contour = outline.contours[0]
            #expect(contour.isCounterclockwise, "\(cap)")
            #expect(contour.isConnected(), "\(cap) produced a broken contour")
        }
    }

    @Test("Orientation does not depend on the direction the line was drawn")
    func directionIndependence() {
        let forward = Outliner.outlineSegment(from: start, to: end,
                                              width: 1.2, cap: .round)
        let backward = Outliner.outlineSegment(from: end, to: start,
                                               width: 1.2, cap: .round)

        #expect(approximately(forward.area, backward.area))
        #expect(backward.contours[0].isCounterclockwise)
    }

    @Test("A diagonal segment outlines to the same area as a horizontal one")
    func diagonalArea() {
        let diagonal = Outliner.outlineSegment(from: .zero,
                                               to: IconPoint(x: 3, y: 4),
                                               width: 1.2, cap: .butt)
        #expect(approximately(diagonal.area, 1.2 * 5))
    }

    @Test("A zero-length segment is a dot only under a round cap")
    func degenerateSegment() {
        let point = IconPoint(x: 4, y: 4)

        let round = Outliner.outlineSegment(from: point, to: point,
                                            width: 2, cap: .round)
        #expect(approximately(round.area, .pi))

        #expect(Outliner.outlineSegment(from: point, to: point,
                                        width: 2, cap: .butt).isEmpty)
    }

    @Test("A zero width produces nothing")
    func zeroWidth() {
        #expect(Outliner.outlineSegment(from: start, to: end,
                                        width: 0, cap: .round).isEmpty)
    }
}

@Suite("Circle outlining")
struct CircleOutliningTests {

    @Test("A stroked circle is an annulus of area 2 pi r w")
    func annulusArea() {
        let radius = 4.0
        for width in testWidths where width / 2 < radius {
            let outline = Outliner.outlineRing(center: IconPoint(x: 8, y: 8),
                                               radius: radius,
                                               width: width)
            #expect(outline.contours.count == 2, "width \(width) should leave a hole")
            #expect(approximately(outline.area, 2 * .pi * radius * width),
                    "width \(width)")
        }
    }

    @Test("The hole runs clockwise so it subtracts")
    func holeOrientation() {
        let outline = Outliner.outlineRing(center: .zero, radius: 4, width: 1.2)

        #expect(outline.contours[0].isCounterclockwise, "outer boundary")
        #expect(!outline.contours[1].isCounterclockwise, "hole")
    }

    @Test("A stroke wider than the circle collapses to a solid disc")
    func swallowedHole() {
        // Radius 1 with width 4 means the inner edge would be at -1.
        let outline = Outliner.outlineRing(center: .zero, radius: 1, width: 4)

        #expect(outline.contours.count == 1, "no hole should remain")
        #expect(approximately(outline.area, .pi * 9), "disc of radius 3")
    }

    @Test("The stroke straddles the centerline evenly")
    func strokeIsCentred() {
        let outline = Outliner.outlineRing(center: .zero, radius: 5, width: 2)
        guard case .arc(let outer) = outline.contours[0].segments[0],
              case .arc(let inner) = outline.contours[1].segments[0] else {
            Issue.record("Expected two arcs")
            return
        }
        #expect(approximately(outer.radius, 6))
        #expect(approximately(inner.radius, 4))
    }
}

@Suite("Arc outlining")
struct ArcOutliningTests {

    private func arc(from start: Double, to end: Double,
                     radius: Double = 4) -> ArcPrimitive {
        ArcPrimitive(center: .zero,
                     radius: radius,
                     startAngle: IconAngle(degrees: start),
                     endAngle: IconAngle(degrees: end))
    }

    @Test("A stroked arc has the area of its annular sector")
    func sectorArea() {
        // Area of an annular sector = sweep/2 * (outer^2 - inner^2), which for
        // a centred stroke is sweep * radius * width.
        for degrees in [45.0, 90.0, 180.0, 270.0] {
            for width in [0.65, 1.2, 2.35] {
                let outline = Outliner.outlineArc(arc(from: 0, to: degrees),
                                                  width: width, cap: .butt)
                let sweep = degrees * .pi / 180
                #expect(approximately(outline.area, sweep * 4 * width, tolerance: 1e-9),
                        "\(degrees) deg at width \(width)")
            }
        }
    }

    @Test("Round caps add one disc across both ends")
    func roundCapArea() {
        let width = 1.2
        let butt = Outliner.outlineArc(arc(from: 0, to: 90),
                                       width: width, cap: .butt)
        let round = Outliner.outlineArc(arc(from: 0, to: 90),
                                        width: width, cap: .round)

        let capArea = .pi * (width / 2) * (width / 2)
        #expect(approximately(round.area - butt.area, capArea, tolerance: 1e-9))
    }

    @Test("A full-circle arc outlines as a ring, with no caps")
    func fullCircle() {
        let full = ArcPrimitive(center: .zero, radius: 4,
                                startAngle: .zero, endAngle: .zero)
        let outline = Outliner.outlineArc(full, width: 1.2, cap: .round)

        #expect(outline.contours.count == 2, "a ring, not a capped arc")
        #expect(approximately(outline.area, 2 * .pi * 4 * 1.2))
    }

    @Test("An arc crossing zero degrees outlines correctly")
    func crossingZero() {
        let outline = Outliner.outlineArc(arc(from: 315, to: 45),
                                          width: 1.2, cap: .butt)
        let sweep = Double.pi / 2
        #expect(approximately(outline.area, sweep * 4 * 1.2, tolerance: 1e-9))
    }

    @Test("A stroke wider than the radius does not invert the outline")
    func strokeWiderThanRadius() {
        // The inner edge clamps at zero rather than going negative, which would
        // otherwise fold the outline inside out.
        let outline = Outliner.outlineArc(arc(from: 0, to: 180, radius: 0.5),
                                          width: 4, cap: .butt)
        #expect(outline.area > 0, "outline inverted")
        #expect(outline.contours[0].isCounterclockwise)
    }

    @Test("Arc outlines are closed")
    func closure() {
        for cap in [LineCap.butt, .round] {
            for degrees in [45.0, 180.0, 300.0] {
                let outline = Outliner.outlineArc(arc(from: 10, to: 10 + degrees),
                                                  width: 1.2, cap: cap)
                #expect(outline.contours[0].isConnected(tolerance: 1e-9),
                        "\(cap) at \(degrees) deg produced a broken contour")
            }
        }
    }
}

@Suite("Rounded rectangle and capsule outlining")
struct RoundedRectOutliningTests {

    private let bounds = IconRect(x: 2, y: 2, width: 8, height: 6)

    /// Area of a rounded rectangle: the box minus the four corner offcuts.
    private func roundedRectArea(_ rect: IconRect, radius: Double) -> Double {
        let radius = max(0, min(radius, min(rect.size.width, rect.size.height) / 2))
        return rect.size.width * rect.size.height
            - (4 - .pi) * radius * radius
    }

    @Test("A stroked rounded rectangle is the outer shape minus the inner")
    func strokeArea() {
        let cornerRadius = 1.5
        for width in [0.65, 1.2, 2.35] {
            let outline = Outliner.outlineRoundedRect(bounds: bounds,
                                                      cornerRadius: cornerRadius,
                                                      width: width)
            let half = width / 2
            let expected = roundedRectArea(bounds.inset(by: -half),
                                           radius: cornerRadius + half)
                - roundedRectArea(bounds.inset(by: half),
                                  radius: max(0, cornerRadius - half))

            #expect(approximately(outline.area, expected, tolerance: 1e-9),
                    "width \(width)")
        }
    }

    @Test("Stroking a sharp corner rounds it outward by half the width")
    func squareCorners() {
        let outline = Outliner.outlineRoundedRect(bounds: bounds,
                                                  cornerRadius: 0,
                                                  width: 1)

        // A round join on a sharp corner sweeps a quarter disc of radius half
        // the stroke width, so the outer boundary is a rounded rectangle even
        // though the centerline is not. The inner boundary stays sharp: its
        // radius clamps at zero.
        let outer = roundedRectArea(bounds.inset(by: -0.5), radius: 0.5)
        let inner = roundedRectArea(bounds.inset(by: 0.5), radius: 0)
        #expect(approximately(outline.area, outer - inner))

        // Confirm the difference from a naive box-minus-box is exactly the
        // four corner offcuts, so this is the join and not an arithmetic slip.
        let naive = 9.0 * 7.0 - 7.0 * 5.0
        #expect(approximately(naive - outline.area, (4 - .pi) * 0.25))
    }

    @Test("A stroke thicker than the shape collapses to a solid")
    func swallowedInterior() {
        let outline = Outliner.outlineRoundedRect(bounds: bounds,
                                                  cornerRadius: 1,
                                                  width: 8)
        #expect(outline.contours.count == 1, "no hole should remain")
        #expect(outline.area > 0)
    }

    @Test("Outer runs counterclockwise and the hole clockwise")
    func orientation() {
        let outline = Outliner.outlineRoundedRect(bounds: bounds,
                                                  cornerRadius: 1.5,
                                                  width: 1.2)
        #expect(outline.contours[0].isCounterclockwise)
        #expect(!outline.contours[1].isCounterclockwise)
    }

    @Test("Both contours are closed")
    func closure() {
        let outline = Outliner.outlineRoundedRect(bounds: bounds,
                                                  cornerRadius: 1.5,
                                                  width: 1.2)
        for contour in outline.contours {
            #expect(contour.isConnected(tolerance: 1e-9))
        }
    }

    @Test("A capsule is a rounded rectangle with the maximum radius")
    func capsule() {
        let capsuleBounds = IconRect(x: 0, y: 0, width: 10, height: 4)
        let outline = Outliner.outlineRoundedRect(bounds: capsuleBounds,
                                                  cornerRadius: 2,
                                                  width: 1)
        let expected = roundedRectArea(capsuleBounds.inset(by: -0.5), radius: 2.5)
            - roundedRectArea(capsuleBounds.inset(by: 0.5), radius: 1.5)
        #expect(approximately(outline.area, expected, tolerance: 1e-9))
    }
}

@Suite("Outlining through the primitive interface")
struct PrimitiveOutliningTests {

    @Test("Every semantic primitive produces a non-empty, closed outline")
    func allPrimitivesOutline() throws {
        let primitives: [IconPrimitive] = [
            .line(LinePrimitive(start: .zero, end: IconPoint(x: 6, y: 0))),
            .circle(CirclePrimitive(center: IconPoint(x: 8, y: 8), radius: 4)),
            .arc(ArcPrimitive(center: IconPoint(x: 8, y: 8), radius: 4,
                              startAngle: IconAngle(degrees: 30),
                              endAngle: IconAngle(degrees: 200))),
            .roundedRect(RoundedRectPrimitive(
                bounds: IconRect(x: 1, y: 1, width: 8, height: 5),
                cornerRadius: 1.5)),
            .capsule(CapsulePrimitive(
                bounds: IconRect(x: 1, y: 1, width: 8, height: 3))),
            .polyline(PolylinePrimitive(points: [
                .zero, IconPoint(x: 4, y: 0), IconPoint(x: 4, y: 4)
            ])),
            .symmetricPath(SymmetricPathPrimitive(
                points: [IconPoint(x: 4, y: 0), IconPoint(x: 6, y: 5)],
                axis: .vertical,
                axisPosition: 8))
        ]

        for primitive in primitives {
            for width in testWidths {
                let outline = try #require(
                    Outliner.outline(primitive, width: width),
                    "\(primitive.kindName) produced no outline")

                #expect(!outline.isEmpty,
                        "\(primitive.kindName) at width \(width) was empty")
                #expect(outline.area > 0,
                        "\(primitive.kindName) at width \(width) had no area")

                for contour in outline.contours {
                    #expect(contour.isConnected(tolerance: 1e-9),
                            "\(primitive.kindName) at width \(width) was not closed")
                }
            }
        }
    }

    @Test("Outlines contain only lines and circular arcs, never polylines")
    func onlyExactCurves() throws {
        // The point of analytic outlining: a stroked circle is two arcs, not a
        // few hundred line segments.
        let circle = IconPrimitive.circle(
            CirclePrimitive(center: .zero, radius: 4))
        let outline = try #require(Outliner.outline(circle, width: 1.2))

        #expect(outline.segmentCount == 2,
                "a ring should be exactly two arcs, got \(outline.segmentCount)")

        let rect = IconPrimitive.roundedRect(RoundedRectPrimitive(
            bounds: IconRect(x: 0, y: 0, width: 8, height: 6), cornerRadius: 1))
        let rectOutline = try #require(Outliner.outline(rect, width: 1))

        // Eight segments per rounded rectangle, two rectangles.
        #expect(rectOutline.segmentCount == 16)
    }

    @Test("Area grows with stroke width for every primitive")
    func monotonicInWidth() throws {
        let primitives: [IconPrimitive] = [
            .line(LinePrimitive(start: .zero, end: IconPoint(x: 6, y: 0))),
            .circle(CirclePrimitive(center: .zero, radius: 4)),
            .arc(ArcPrimitive(center: .zero, radius: 4,
                              startAngle: .zero,
                              endAngle: IconAngle(degrees: 120)))
        ]

        for primitive in primitives {
            var previous = 0.0
            for width in testWidths {
                let outline = try #require(Outliner.outline(primitive, width: width))
                #expect(outline.area > previous,
                        "\(primitive.kindName) did not grow at width \(width)")
                previous = outline.area
            }
        }
    }

    @Test("Compounds and imported paths do not outline")
    func unoutlinable() {
        let compound = IconPrimitive.compound(
            CompoundPrimitive(operation: .union, children: []))
        let imported = IconPrimitive.importedPath(
            ImportedPathPrimitive(pathData: "M0 0 L4 4"))

        #expect(Outliner.outline(compound, width: 1) == nil)
        #expect(Outliner.outline(imported, width: 1) == nil)
    }
}
