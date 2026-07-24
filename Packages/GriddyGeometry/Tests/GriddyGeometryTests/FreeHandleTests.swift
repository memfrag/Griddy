//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
@testable import GriddyGeometry

@Suite("Free tangent handles")
struct FreeHandleTests {

    private let points = [IconPoint(x: 0, y: 0), IconPoint(x: 6, y: 0),
                          IconPoint(x: 12, y: 0)]

    @Test("A free handle steers the curve toward its control point")
    func handleSteersCurve() {
        // Middle point pulled up by a big out-handle; the curve should bulge up.
        let handles: [CurveHandle?] = [
            nil,
            CurveHandle(inOffset: IconVector(dx: -3, dy: 3),
                        outOffset: IconVector(dx: 3, dy: 3)),
            nil
        ]
        let arcs = Biarc.fit(through: points, closed: false,
                             inSmoothness: [1, 1, 1], outSmoothness: [1, 1, 1],
                             handles: handles)

        // Sample the centerline: some point should rise well above the baseline.
        let highest = arcs.flatMap { seg -> [Double] in
            switch seg {
            case .line(let a, let b): [a.y, b.y]
            case .arc(let a): [a.startPoint.y, a.endPoint.y,
                               a.point(atAngle: IconAngle(
                                radians: (a.startAngle.radians + a.endAngle.radians) / 2)).y]
            }
        }.max() ?? 0
        #expect(highest > 1, "handle did not lift the curve, peak \(highest)")
    }

    @Test("A curve with free handles still passes through the points")
    func passesThroughPoints() {
        let handles: [CurveHandle?] = [
            nil,
            CurveHandle(inOffset: IconVector(dx: -2, dy: 4),
                        outOffset: IconVector(dx: 4, dy: -1)),  // asymmetric
            nil
        ]
        let arcs = Biarc.fit(through: points, closed: false, handles: handles)
        for point in points {
            #expect(arcs.contains {
                $0.start.distance(to: point) < 1e-6 || $0.end.distance(to: point) < 1e-6
            }, "missed \(point)")
        }
    }

    @Test("The derived handle reproduces the smoothness curve")
    func derivedSeedsFree() {
        // A point's derived handle, fed back as an explicit free handle, should
        // give the same curve -- so switching to free mode does not jump.
        let smoothness = [1.0, 1, 1]
        let plain = Biarc.fit(through: points, closed: false, smoothness: smoothness)

        let offsets = Biarc.handleOffsets(points, closed: false,
                                          inSmoothness: smoothness,
                                          outSmoothness: smoothness, handles: [])
        let seeded: [CurveHandle?] = points.indices.map {
            CurveHandle(inOffset: offsets.in[$0], outOffset: offsets.out[$0])
        }
        let free = Biarc.fit(through: points, closed: false, handles: seeded)
        #expect(free == plain)
    }
}
