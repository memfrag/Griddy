//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
@testable import GriddyGeometry

/// The largest distance any point on the cubics strays from the true arc.
///
/// Sampling densely is the only honest check: matching endpoints proves
/// nothing about the middle, which is exactly where an approximation goes
/// wrong.
private func maximumRadialError(_ arc: ArcSegment, samples: Int = 200) -> Double {
    let cubics = ArcToCubic.cubics(for: arc)
    var worst = 0.0

    for cubic in cubics {
        for step in 0...samples {
            let point = cubic.point(at: Double(step) / Double(samples))
            let distance = point.distance(to: arc.center)
            worst = max(worst, abs(distance - arc.radius))
        }
    }
    return worst
}

@Suite("Arc to cubic conversion")
struct ArcToCubicTests {

    private func arc(from start: Double,
                     to end: Double,
                     radius: Double = 10,
                     clockwise: Bool = false) -> ArcSegment {
        ArcSegment(center: IconPoint(x: 3, y: -2),
                   radius: radius,
                   startAngle: IconAngle(degrees: start),
                   endAngle: IconAngle(degrees: end),
                   isClockwise: clockwise)
    }

    @Test("Endpoints land exactly on the arc")
    func endpoints() throws {
        let subject = arc(from: 20, to: 160)
        let cubics = ArcToCubic.cubics(for: subject)

        let first = try #require(cubics.first)
        let last = try #require(cubics.last)

        #expect(first.start.distance(to: subject.startPoint) < 1e-9)
        #expect(last.end.distance(to: subject.endPoint) < 1e-9)
    }

    @Test("Segments join without gaps")
    func continuity() {
        let cubics = ArcToCubic.cubics(for: arc(from: 0, to: 350))

        for index in 0..<(cubics.count - 1) {
            #expect(cubics[index].end.distance(to: cubics[index + 1].start) < 1e-9,
                    "gap between segment \(index) and \(index + 1)")
        }
    }

    @Test("Arcs are split so no segment exceeds a quarter turn")
    func splitting() {
        #expect(ArcToCubic.cubics(for: arc(from: 0, to: 45)).count == 1)
        #expect(ArcToCubic.cubics(for: arc(from: 0, to: 90)).count == 1)
        #expect(ArcToCubic.cubics(for: arc(from: 0, to: 91)).count == 2)
        #expect(ArcToCubic.cubics(for: arc(from: 0, to: 180)).count == 2)
        #expect(ArcToCubic.cubics(for: arc(from: 0, to: 270)).count == 3)

        // A full circle is four quarter turns.
        let full = ArcSegment(center: .zero, radius: 5,
                              startAngle: .zero, endAngle: .zero)
        #expect(ArcToCubic.cubics(for: full).count == 4)
    }

    @Test("The approximation stays within a thousandth of a percent of the radius")
    func accuracy() {
        // The quarter-turn cubic approximation is good to about 2.7e-4 of the
        // radius. Anything materially worse means the handle length is wrong.
        for sweep in [15.0, 45.0, 90.0, 137.0, 180.0, 270.0, 359.0] {
            let subject = arc(from: 12, to: 12 + sweep)
            let error = maximumRadialError(subject)

            #expect(error < subject.radius * 3e-4,
                    "sweep \(sweep) drifted \(error) from radius \(subject.radius)")
        }
    }

    @Test("Accuracy is independent of radius")
    func scaleInvariance() {
        for radius in [0.5, 1.0, 10.0, 500.0] {
            let subject = arc(from: 0, to: 200, radius: radius)
            #expect(maximumRadialError(subject) < radius * 3e-4,
                    "radius \(radius)")
        }
    }

    @Test("Clockwise arcs sweep the short way, not the long way")
    func direction() {
        // A clockwise arc from 90 to 0 passes through 45 degrees. If the sign
        // were wrong it would take the 270 degree route instead, which still
        // joins its endpoints and would pass a naive endpoint check.
        let clockwise = arc(from: 90, to: 0, clockwise: true)
        let cubics = ArcToCubic.cubics(for: clockwise)

        let midpoint = cubics[cubics.count / 2].point(at: 0.5)
        let expected = clockwise.point(atAngle: IconAngle(degrees: 45))

        #expect(midpoint.distance(to: expected) < clockwise.radius * 1e-2,
                "clockwise arc took the wrong way round")
        #expect(cubics.count == 1, "a quarter turn needs one segment either way")
    }

    @Test("Counterclockwise arcs curve the other way")
    func counterclockwiseDirection() {
        let counterclockwise = arc(from: 0, to: 90)
        let cubics = ArcToCubic.cubics(for: counterclockwise)

        let midpoint = cubics[0].point(at: 0.5)
        let expected = counterclockwise.point(atAngle: IconAngle(degrees: 45))
        #expect(midpoint.distance(to: expected) < counterclockwise.radius * 1e-2)
    }

    @Test("Degenerate arcs produce nothing rather than garbage")
    func degenerate() {
        let zeroRadius = ArcSegment(center: .zero, radius: 0,
                                    startAngle: .zero,
                                    endAngle: IconAngle(degrees: 90))
        #expect(ArcToCubic.cubics(for: zeroRadius).isEmpty)
    }
}
