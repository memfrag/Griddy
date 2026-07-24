//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
@testable import GriddyGeometry

@Suite("Per-point smoothness")
struct BiarcSmoothnessTests {

    // A V shape: down to the middle, back up. The middle point is the corner.
    private let points = [IconPoint(x: 0, y: 4),
                          IconPoint(x: 4, y: 0),
                          IconPoint(x: 8, y: 4)]

    @Test("A corner point (smoothness 0) yields straight segments")
    func cornerIsStraight() {
        let segments = Biarc.fit(through: points, closed: false,
                                 smoothness: [1, 0, 1])
        // With the apex sharp, both sides collapse to lines meeting at it.
        let allLines = segments.allSatisfy { if case .line = $0 { true } else { false } }
        #expect(allLines, "expected straight sides, got \(segments)")

        // And a line actually reaches the apex.
        #expect(segments.contains { $0.end.distance(to: points[1]) < 1e-6
                                    || $0.start.distance(to: points[1]) < 1e-6 })
    }

    @Test("A smooth point (smoothness 1) yields arcs")
    func smoothHasArcs() {
        let segments = Biarc.fit(through: points, closed: false,
                                 smoothness: [1, 1, 1])
        #expect(segments.contains { if case .arc = $0 { true } else { false } })
    }

    @Test("Smoothness still passes through every point")
    func passesThrough() {
        for s in [[1.0, 0, 1], [1, 0.5, 1], [0, 0, 0]] {
            let segments = Biarc.fit(through: points, closed: false, smoothness: s)
            for point in points {
                #expect(segments.contains {
                    $0.start.distance(to: point) < 1e-6
                        || $0.end.distance(to: point) < 1e-6
                }, "smoothness \(s) missed \(point)")
            }
        }
    }

    @Test("Missing smoothness values default to fully smooth")
    func defaultsToSmooth() {
        let withArray = Biarc.fit(through: points, closed: false, smoothness: [1, 1, 1])
        let without = Biarc.fit(through: points, closed: false)
        #expect(withArray.count == without.count)
    }
}
