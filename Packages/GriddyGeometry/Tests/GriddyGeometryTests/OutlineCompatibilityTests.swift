//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
@testable import GriddyGeometry

/// The three authored stroke weights.
private let weights: [Double] = [0.65, 1.2, 2.35]

/// A circle crossed by an overlapping line, at one weight.
///
/// This is the shape that Apple's app actually rejected: two primitives whose
/// union cuts differently as the stroke grows.
private func circleAndLine(width: Double) -> OutlinePath {
    let ring = Outliner.outlineRing(center: IconPoint(x: 8, y: 8),
                                    radius: 4,
                                    width: width)
    let handle = Outliner.outlineSegment(from: IconPoint(x: 10, y: 6),
                                         to: IconPoint(x: 14, y: 2),
                                         width: width,
                                         cap: .round)
    return BooleanSolver.combine(ring, handle, operation: .union)
}

/// Samples a contour at even fractions of its length.
private func samples(_ contour: OutlineContour, count: Int = 400) -> [IconPoint] {
    let total = contour.length
    guard total > 0 else {
        return []
    }

    var points: [IconPoint] = []
    for step in 0..<count {
        let target = Double(step) / Double(count) * total
        var accumulated = 0.0
        for segment in contour.segments {
            let length = segment.length
            if accumulated + length >= target || segment == contour.segments.last {
                let local = length > 0 ? (target - accumulated) / length : 0
                points.append(segment.point(at: min(1, max(0, local))))
                break
            }
            accumulated += length
        }
    }
    return points
}

/// The furthest any sampled point of one contour lies from the other's outline.
///
/// Distances to the target are exact, not sampled: sampling the target would
/// floor this measurement at the sample spacing and make a genuinely unmoved
/// shape look like it had drifted.
private func maximumDeviation(_ first: OutlineContour,
                              _ second: OutlineContour) -> Double {
    var worst = 0.0
    for point in samples(first) {
        let nearest = second.segments.reduce(Double.infinity) {
            min($0, $1.distance(to: point))
        }
        worst = max(worst, nearest)
    }
    return worst
}

@Suite("Outline compatibility")
struct OutlineCompatibilityTests {

    @Test("The real failing case reconciles")
    func realCaseReconciles() throws {
        let masters = weights.map(circleAndLine)

        // Before: the mismatch Apple refused.
        let before = masters.map { $0.contours.reduce(0) { $0 + $1.segments.count } }
        #expect(Set(before).count > 1,
                "expected the masters to disagree, got \(before)")

        let after = try OutlineCompatibility.reconcile(masters)
        let counts = after.map { $0.contours.reduce(0) { $0 + $1.segments.count } }

        #expect(Set(counts).count == 1,
                "masters still disagree after reconciling: \(counts)")
    }

    @Test("Every region has the same segment count in every master")
    func perContourCounts() throws {
        let reconciled = try OutlineCompatibility.reconcile(weights.map(circleAndLine))
        let reference = reconciled[0]

        for path in reconciled.dropFirst() {
            #expect(path.contours.count == reference.contours.count)
            for (index, contour) in path.contours.enumerated() {
                #expect(contour.segments.count
                        == reference.contours[index].segments.count,
                        "region \(index) differs")
            }
        }
    }

    @Test("Reconciling changes the description, not the shape")
    func shapeIsPreserved() throws {
        let masters = weights.map(circleAndLine)
        let reconciled = try OutlineCompatibility.reconcile(masters)

        // The whole method rests on this: splitting a segment leaves the curve
        // exactly where it was. Area is the sharpest global check, and sampled
        // deviation catches a piece that moved without changing the total.
        for (index, master) in masters.enumerated() {
            let detail = "master \(index) changed area: "
                + "\(master.area) -> \(reconciled[index].area)"
            #expect(abs(reconciled[index].area - master.area) < 1e-6, "\(detail)")
        }

        for (index, master) in masters.enumerated() {
            for original in master.contours {
                let nearest = reconciled[index].contours.min {
                    abs($0.area - original.area) < abs($1.area - original.area)
                }
                let match = try #require(nearest)
                #expect(maximumDeviation(original, match) < 1e-6,
                        "master \(index) moved geometry")
            }
        }
    }

    @Test("Reconciled contours are still closed")
    func stillClosed() throws {
        let reconciled = try OutlineCompatibility.reconcile(weights.map(circleAndLine))

        for path in reconciled {
            for contour in path.contours {
                #expect(contour.isConnected(tolerance: 1e-6))
            }
        }
    }

    @Test("Winding survives, so holes stay holes")
    func windingPreserved() throws {
        let masters = weights.map(circleAndLine)
        let reconciled = try OutlineCompatibility.reconcile(masters)

        for (index, path) in reconciled.enumerated() {
            let before = masters[index].contours.map(\.isCounterclockwise).sorted { $0 && !$1 }
            let after = path.contours.map(\.isCounterclockwise).sorted { $0 && !$1 }
            #expect(before == after, "master \(index) changed winding")
        }
    }

    @Test("Already-compatible masters are left alone structurally")
    func alreadyCompatible() throws {
        // A plain ring has the same structure at every weight: no booleans, so
        // nothing to shift.
        let rings = weights.map {
            Outliner.outlineRing(center: .zero, radius: 5, width: $0)
        }
        let reconciled = try OutlineCompatibility.reconcile(rings)

        let counts = reconciled.map { $0.contours.reduce(0) { $0 + $1.segments.count } }
        #expect(Set(counts).count == 1)

        for (index, ring) in rings.enumerated() {
            #expect(abs(reconciled[index].area - ring.area) < 1e-9)
        }
    }

    @Test("Correspondence is by geometry, not by index")
    func correspondenceIgnoresOrder() throws {
        let masters = weights.map(circleAndLine)

        // Reversing one master's contour order must not change the outcome:
        // boolean stitching emits contours in whatever order it finds them.
        var shuffled = masters
        shuffled[2] = OutlinePath(contours: masters[2].contours.reversed())

        let straight = try OutlineCompatibility.reconcile(masters)
        let scrambled = try OutlineCompatibility.reconcile(shuffled)

        let a = straight.map { $0.contours.map(\.segments.count) }
        let b = scrambled.map { $0.contours.map(\.segments.count) }
        #expect(a == b, "ordering changed the result: \(a) against \(b)")
    }

    @Test("Masters enclosing different numbers of regions are refused")
    func regionCountMismatch() {
        // A stroke thick enough to swallow the hole genuinely changes the
        // topology: two regions become one. No amount of point insertion
        // creates a correspondence, so this must fail rather than invent one.
        let thin = Outliner.outlineRing(center: .zero, radius: 1, width: 0.5)
        let swallowed = Outliner.outlineRing(center: .zero, radius: 1, width: 4)

        #expect(thin.contours.count == 2)
        #expect(swallowed.contours.count == 1)

        #expect(throws: OutlineCompatibility.Failure.contourCountMismatch(
            counts: [2, 1])) {
            try OutlineCompatibility.reconcile([thin, swallowed])
        }
    }

    @Test("The refusal explains itself and suggests a fix")
    func failureMessage() {
        let failure = OutlineCompatibility.Failure.contourCountMismatch(counts: [3, 2])

        #expect(failure.errorDescription?.contains("different numbers") == true)
        #expect(failure.recoverySuggestion?.contains("Thicken") == true)
    }

    @Test("An empty master is refused rather than silently reconciled")
    func emptyMaster() {
        let ring = Outliner.outlineRing(center: .zero, radius: 4, width: 1)

        #expect(throws: OutlineCompatibility.Failure.emptyMaster(index: 1)) {
            try OutlineCompatibility.reconcile([ring, .empty])
        }
    }

    @Test("A single master passes through untouched")
    func singleMaster() throws {
        let ring = Outliner.outlineRing(center: .zero, radius: 4, width: 1)
        #expect(try OutlineCompatibility.reconcile([ring]) == [ring])
    }

    @Test("Nearby boundaries merge instead of leaving hairline segments")
    func mergesNearbyBoundaries() {
        let merged = OutlineCompatibility.mergeNearby([0.2, 0.20001, 0.5, 0.90])

        #expect(merged.count == 3, "expected 0.2, 0.5 and 0.9, got \(merged)")
        #expect(merged.contains { abs($0 - 0.5) < 1e-9 })
    }

    @Test("Boundaries at the very start or end are dropped")
    func dropsEndpoints() {
        // Zero and one are the contour's own closure, not interior cuts;
        // splitting there would append a zero-length segment.
        let merged = OutlineCompatibility.mergeNearby([0, 0.5, 1])
        #expect(merged == [0.5])
    }
}
