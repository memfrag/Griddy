//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
@testable import GriddyGeometry

@Suite("Biarc fitting")
struct BiarcTests {

    /// Where an outline segment starts and ends, and its tangent at each end.
    private func endpoints(_ segment: OutlineSegment) -> (IconPoint, IconPoint) {
        (segment.start, segment.end)
    }

    @Test("A single arc leaves its start along the given tangent")
    func arcRespectsTangent() {
        let a = IconPoint(x: 0, y: 0)
        let b = IconPoint(x: 4, y: 4)
        let segment = Biarc.arc(from: a, tangent: IconVector(dx: 1, dy: 0), to: b)

        #expect(segment.start.distance(to: a) < 1e-9)
        #expect(segment.end.distance(to: b) < 1e-9)

        // Tangent at the start, sampled just along the arc, should point +x.
        guard case .arc(let arc) = segment else {
            Issue.record("expected an arc"); return
        }
        let step = (arc.isClockwise ? -1.0 : 1.0) * 1e-4
        let near = arc.point(atAngle: IconAngle(radians: arc.startAngle.radians + step))
        let heading = a.vector(to: near).normalized!
        #expect(abs(heading.dy) < 1e-3, "leaves horizontally, dy=\(heading.dy)")
        #expect(heading.dx > 0)
    }

    @Test("Collinear points give a straight segment")
    func collinearIsLine() {
        let segment = Biarc.arc(from: IconPoint(x: 0, y: 0),
                                tangent: IconVector(dx: 1, dy: 0),
                                to: IconPoint(x: 5, y: 0))
        guard case .line = segment else {
            Issue.record("expected a line"); return
        }
    }

    @Test("The fitted centerline passes through every point")
    func passesThroughPoints() {
        let points = [IconPoint(x: 0, y: 0), IconPoint(x: 3, y: 4),
                      IconPoint(x: 7, y: 2), IconPoint(x: 10, y: 6)]
        let segments = Biarc.fit(through: points, closed: false)
        #expect(!segments.isEmpty)

        // Each interior point is where one biarc ends and the next begins;
        // some segment start or end must land on it.
        for point in points {
            let touches = segments.contains {
                $0.start.distance(to: point) < 1e-6
                    || $0.end.distance(to: point) < 1e-6
            }
            #expect(touches, "no segment reaches \(point)")
        }
    }

    @Test("Consecutive segments join without gaps")
    func segmentsConnect() {
        let points = [IconPoint(x: 0, y: 0), IconPoint(x: 4, y: 3),
                      IconPoint(x: 9, y: 1)]
        let segments = Biarc.fit(through: points, closed: false)
        for (a, b) in zip(segments, segments.dropFirst()) {
            #expect(a.end.distance(to: b.start) < 1e-6,
                    "gap between \(a.end) and \(b.start)")
        }
    }

    @Test("A closed spline returns to its first point")
    func closedWrapsAround() {
        let points = [IconPoint(x: 0, y: 0), IconPoint(x: 6, y: 0),
                      IconPoint(x: 6, y: 6), IconPoint(x: 0, y: 6)]
        let segments = Biarc.fit(through: points, closed: true)
        #expect(segments.first!.start.distance(to: segments.last!.end) < 1e-6)
    }

    @Test("Fewer than two points has no curve")
    func needsTwoPoints() {
        #expect(Biarc.fit(through: [IconPoint(x: 1, y: 1)], closed: false).isEmpty)
        #expect(Biarc.fit(through: [], closed: false).isEmpty)
    }
}
