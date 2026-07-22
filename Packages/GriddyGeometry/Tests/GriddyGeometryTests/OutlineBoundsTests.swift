//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
@testable import GriddyGeometry

@Suite("Arc bounds")
struct ArcBoundsTests {

    @Test("A full circle bounds to its enclosing square")
    func fullCircle() {
        let arc = ArcSegment(center: IconPoint(x: 10, y: 10),
                             radius: 4,
                             startAngle: IconAngle(radians: 0),
                             endAngle: IconAngle(radians: 0),
                             isClockwise: false)
        let bounds = arc.bounds
        #expect(abs(bounds.minX - 6) < 1e-9, "minX \(bounds.minX)")
        #expect(abs(bounds.maxX - 14) < 1e-9, "maxX \(bounds.maxX)")
        #expect(abs(bounds.minY - 6) < 1e-9)
        #expect(abs(bounds.maxY - 14) < 1e-9)
    }

    @Test("A quarter arc bounds to its endpoints, not its circle")
    func quarterArc() {
        // From angle 0 (right) counterclockwise to pi/2 (top).
        let arc = ArcSegment(center: .zero, radius: 10,
                             startAngle: IconAngle(radians: 0),
                             endAngle: IconAngle(radians: .pi / 2),
                             isClockwise: false)
        let bounds = arc.bounds
        #expect(abs(bounds.maxX - 10) < 1e-9, "sweeps through angle 0")
        #expect(abs(bounds.minX - 0) < 1e-9, "does not reach the left of the circle")
        #expect(abs(bounds.maxY - 10) < 1e-9, "sweeps through pi/2")
        #expect(abs(bounds.minY - 0) < 1e-9)
    }

    @Test("Clockwise arcs sweep the other way")
    func clockwise() {
        // Clockwise from pi/2 (top) to 0 (right): the mirror of the above.
        let arc = ArcSegment(center: .zero, radius: 10,
                             startAngle: IconAngle(radians: .pi / 2),
                             endAngle: IconAngle(radians: 0),
                             isClockwise: true)
        let bounds = arc.bounds
        #expect(abs(bounds.maxX - 10) < 1e-9, "maxX \(bounds.maxX)")
        #expect(abs(bounds.minX - 0) < 1e-9, "minX \(bounds.minX)")
        #expect(abs(bounds.maxY - 10) < 1e-9)
    }

    @Test("An arc crossing zero still finds the rightmost point")
    func crossingZero() {
        // From 7pi/4 counterclockwise to pi/4, passing through angle 0.
        let arc = ArcSegment(center: .zero, radius: 10,
                             startAngle: IconAngle(radians: 7 * .pi / 4),
                             endAngle: IconAngle(radians: .pi / 4),
                             isClockwise: false)
        #expect(abs(arc.bounds.maxX - 10) < 1e-9,
                "maxX \(arc.bounds.maxX) -- angle 0 lies inside this sweep")
    }

    @Test("An arc avoiding zero does not claim the rightmost point")
    func avoidingZero() {
        // From pi/4 counterclockwise to 7pi/4, the long way round, avoiding 0.
        let arc = ArcSegment(center: .zero, radius: 10,
                             startAngle: IconAngle(radians: .pi / 4),
                             endAngle: IconAngle(radians: 7 * .pi / 4),
                             isClockwise: false)
        let expected = 10 * cos(Double.pi / 4)
        #expect(abs(arc.bounds.maxX - expected) < 1e-9,
                "maxX \(arc.bounds.maxX) should be the endpoints' \(expected)")
    }
}
