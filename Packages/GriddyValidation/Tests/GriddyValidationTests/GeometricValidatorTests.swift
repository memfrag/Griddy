//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
import GriddyGeometry
import GriddyDocument
import GriddySymbols
@testable import GriddyValidation

@Suite("Geometric validation")
struct GeometricValidatorTests {

    @Test("An empty document is not an error")
    func emptyIsQuiet() {
        // Nothing drawn yet is where every document starts.
        #expect(GeometricValidator.issues(in: blankDocument()).isEmpty)
    }

    @Test("An ordinary drawing reports nothing")
    func ordinaryIsClean() {
        var document = blankDocument()
        document.addPrimitive(.circle(
            CirclePrimitive(center: IconPoint(x: 12, y: 8), radius: 4)))

        let issues = GeometricValidator.issues(in: document)
        #expect(issues.isEmpty, "\(issues.map(\.message))")
    }

    @Test("Overlapping primitives still reconcile")
    func overlapReconciles() {
        // The shape that produced both Apple rejections: a circle crossed by a
        // line, whose boolean result cuts at different places per weight.
        var document = blankDocument()
        let centre = IconPoint(x: 12, y: 8)
        document.addPrimitive(.circle(
            CirclePrimitive(center: centre, radius: 5)))
        document.addPrimitive(.line(LinePrimitive(
            start: IconPoint(x: centre.x + 3, y: centre.y - 3),
            end: IconPoint(x: centre.x + 8, y: centre.y - 8))))

        let errors = GeometricValidator.issues(in: document)
            .filter { $0.severity == .error }
        #expect(errors.isEmpty, "\(errors.map(\.message))")
    }

    @Test("Differing contour counts are reported")
    func detectsContourCountMismatch() {
        let square = OutlinePath(contours: [OutlineContour(segments: [
            .line(from: IconPoint(x: 0, y: 0), to: IconPoint(x: 4, y: 0)),
            .line(from: IconPoint(x: 4, y: 0), to: IconPoint(x: 4, y: 4)),
            .line(from: IconPoint(x: 4, y: 4), to: IconPoint(x: 0, y: 0))
        ])])
        let two = OutlinePath(contours: square.contours + square.contours)

        // This one used to trap on an out-of-range index inside the exporter
        // rather than being reported.
        let issues = GeometricValidator.interpolability(of: [two, square])
        #expect(issues.count == 1)
        #expect(issues.first?.message.contains("separate shapes") == true)

        // And converting them no longer crashes.
        _ = [two, square].svgCommandsForReconciledMasters { _, point in point }
    }

    @Test("Masters differing in kind at one index are forced to agree")
    func kindsAreForcedToAgree() {
        // A triangle of straight edges against one whose third edge is an arc.
        // Equal segment counts, different kinds -- which is what got an export
        // refused despite 2 subpaths and 50 commands in every master.
        //
        // Export closes this by emitting a curve wherever any master curves, so
        // the correct result here is *no issue*. Reporting one would mean the
        // validator disagrees with the file that actually gets written.
        let a = IconPoint(x: 0, y: 0)
        let b = IconPoint(x: 10, y: 0)
        let c = IconPoint(x: 10, y: 10)

        let straight = OutlinePath(contours: [OutlineContour(segments: [
            .line(from: a, to: b), .line(from: b, to: c), .line(from: c, to: a)
        ])])
        let curved = OutlinePath(contours: [OutlineContour(segments: [
            .line(from: a, to: b), .line(from: b, to: c),
            .arc(ArcSegment(center: IconPoint(x: 5, y: 5), radius: 7.07,
                            startAngle: IconAngle(radians: .pi / 4),
                            endAngle: IconAngle(radians: 5 * .pi / 4),
                            isClockwise: false))
        ])])

        #expect(GeometricValidator.interpolability(of: [straight, curved])
                .isEmpty)
    }

    @Test("Unequal segment counts are reported")
    func detectsUnequalSegmentCounts() {
        // The case export cannot rescue: reconciliation returning masters of
        // different lengths. The converter's bounds check then skips segments
        // for the short master and the sequences diverge in the written file.
        let a = IconPoint(x: 0, y: 0)
        let b = IconPoint(x: 10, y: 0)
        let c = IconPoint(x: 10, y: 10)

        let triangle = OutlinePath(contours: [OutlineContour(segments: [
            .line(from: a, to: b), .line(from: b, to: c), .line(from: c, to: a)
        ])])
        let quad = OutlinePath(contours: [OutlineContour(segments: [
            .line(from: a, to: b), .line(from: b, to: c),
            .line(from: c, to: IconPoint(x: 0, y: 10)),
            .line(from: IconPoint(x: 0, y: 10), to: a)
        ])])

        let issues = GeometricValidator.interpolability(of: [triangle, quad])
        #expect(issues.count == 1)
        #expect(issues.first?.severity == .error)
        #expect(issues.first?.message.contains("segments") == true)
    }

    @Test("Identical masters raise nothing")
    func identicalMastersPass() {
        let square = OutlinePath(contours: [OutlineContour(segments: [
            .line(from: IconPoint(x: 0, y: 0), to: IconPoint(x: 4, y: 0)),
            .line(from: IconPoint(x: 4, y: 0), to: IconPoint(x: 4, y: 4)),
            .line(from: IconPoint(x: 4, y: 4), to: IconPoint(x: 0, y: 0))
        ])])
        #expect(GeometricValidator.interpolability(of: [square, square, square])
                .isEmpty)
    }

    @Test("Differing left bearings are reported as sideways drift")
    func detectsBearingDrift() {
        var document = blankDocument()
        document.addPrimitive(.circle(
            CirclePrimitive(center: IconPoint(x: 12, y: 8), radius: 4)))

        // A per-weight override on one master only.
        document.margins.override(
            GlyphMetrics(leftSideBearing: 4, rightSideBearing: 2), for: .black)

        let issues = GeometricValidator.issues(in: document)
            .filter { $0.category == .visual }
        #expect(issues.count == 1)
        #expect(issues.first?.message.contains("drift") == true)
    }

    @Test("Differing right bearings alone are accepted")
    func rightBearingsMayDiffer() {
        var document = blankDocument()
        document.addPrimitive(.circle(
            CirclePrimitive(center: IconPoint(x: 12, y: 8), radius: 4)))

        // takeoutbag.and.cup.and.straw does exactly this: a constant left
        // bearing with right bearings of 6.67, 4.09 and 2.36. It is optical
        // spacing, not a defect, and must not be reported as one.
        let bearing = document.coordinateSystem.standardSideBearing
        for (weight, right) in zip(SymbolWeight.authored, [2.5, 1.5, 0.5]) {
            document.margins.override(
                GlyphMetrics(leftSideBearing: bearing, rightSideBearing: right),
                for: weight)
        }

        let issues = GeometricValidator.issues(in: document)
            .filter { $0.category == .visual }
        #expect(issues.isEmpty, "\(issues.map(\.message))")
    }
}
