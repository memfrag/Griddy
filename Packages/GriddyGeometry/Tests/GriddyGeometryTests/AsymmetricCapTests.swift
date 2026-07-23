//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
@testable import GriddyGeometry

@Suite("Asymmetric line caps")
struct AsymmetricCapTests {

    private let start = IconPoint(x: 0, y: 0)
    private let end = IconPoint(x: 10, y: 0)

    @Test("A round end contributes an arc; a butt end does not")
    func mixedCapsHaveOneArc() {
        // Round start, butt end: exactly one cap arc, at the start.
        let outline = Outliner.outlineSegment(from: start, to: end, width: 2,
                                              startCap: .round, endCap: .butt)
        let contour = try! #require(outline.contours.first)
        let arcs = contour.segments.filter { if case .arc = $0 { true } else { false } }
        #expect(arcs.count == 1)
    }

    @Test("Two round ends give two arcs, two butt ends give none")
    func symmetricExtremes() {
        func arcCount(_ startCap: LineCap, _ endCap: LineCap) -> Int {
            let outline = Outliner.outlineSegment(from: start, to: end, width: 2,
                                                  startCap: startCap, endCap: endCap)
            return outline.contours.first?.segments.filter {
                if case .arc = $0 { true } else { false }
            }.count ?? 0
        }
        #expect(arcCount(.round, .round) == 2)
        #expect(arcCount(.butt, .butt) == 0)
    }

    @Test("A square end extends only its own end")
    func squareExtendsOneEnd() {
        // Square start, butt end: the outline reaches half a width past the
        // start (to x = -1) but not past the end.
        let outline = Outliner.outlineSegment(from: start, to: end, width: 2,
                                              startCap: .square, endCap: .butt)
        let bounds = try! #require(outline.bounds)
        #expect(abs(bounds.minX - (-1)) < 1e-9, "start extended to -1")
        #expect(abs(bounds.maxX - 10) < 1e-9, "end not extended")
    }

    @Test("The single-cap overload matches both ends equal")
    func overloadAgrees() {
        let viaOne = Outliner.outlineSegment(from: start, to: end, width: 2,
                                             cap: .round)
        let viaTwo = Outliner.outlineSegment(from: start, to: end, width: 2,
                                             startCap: .round, endCap: .round)
        #expect(viaOne == viaTwo)
    }
}
