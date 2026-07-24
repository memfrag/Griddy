//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
@testable import GriddyGeometry

@Suite("Cubic approximation")
struct CubicApproxTests {

    private let p0 = IconPoint(x: 0, y: 0)
    private let c0 = IconPoint(x: 2, y: 6)
    private let c1 = IconPoint(x: 8, y: 6)
    private let p1 = IconPoint(x: 10, y: 0)

    @Test("The arc chain starts and ends at the cubic's endpoints")
    func matchesEndpoints() {
        let arcs = Biarc.approximateCubic(p0, c0, c1, p1)
        #expect(arcs.first!.start.distance(to: p0) < 1e-6)
        #expect(arcs.last!.end.distance(to: p1) < 1e-6)
    }

    @Test("The arc chain stays within tolerance of the cubic")
    func staysClose() {
        let tolerance = 0.02
        let arcs = Biarc.approximateCubic(p0, c0, c1, p1, tolerance: tolerance)
        // Sample the cubic densely; every point must be near some arc.
        for step in 0...20 {
            let t = Double(step) / 20
            let point = Biarc.cubicPoint(p0, c0, c1, p1, at: t)
            let nearest = arcs.map { $0.distance(to: point) }.min() ?? .infinity
            #expect(nearest < tolerance * 2, "t=\(t) off by \(nearest)")
        }
    }

    @Test("A straight cubic becomes a line")
    func straightIsLine() {
        // Control points on the line from (0,0) to (9,0).
        let arcs = Biarc.approximateCubic(IconPoint(x: 0, y: 0),
                                          IconPoint(x: 3, y: 0),
                                          IconPoint(x: 6, y: 0),
                                          IconPoint(x: 9, y: 0))
        #expect(arcs.allSatisfy { if case .line = $0 { true } else { false } })
    }

    @Test("Consecutive arcs connect")
    func connects() {
        let arcs = Biarc.approximateCubic(p0, c0, c1, p1)
        for (a, b) in zip(arcs, arcs.dropFirst()) {
            #expect(a.end.distance(to: b.start) < 1e-6)
        }
    }
}
