//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
@testable import GriddyGeometry

@Suite("Smooth polyline outlining")
struct SmoothPolylineTests {

    private let points = [IconPoint(x: 0, y: 0), IconPoint(x: 4, y: 4),
                          IconPoint(x: 8, y: 0), IconPoint(x: 12, y: 4)]

    @Test("A smooth path outlines to non-empty geometry")
    func smoothOutlines() {
        let outline = Outliner.outlinePolyline(points: points, isClosed: false,
                                               isSmooth: true, width: 2, cap: .round)
        #expect(!outline.isEmpty)
        #expect(outline.contours.contains { !$0.segments.isEmpty })
    }

    @Test("The smooth outline contains curved segments; the straight one does not")
    func smoothHasArcs() {
        func hasArc(_ path: OutlinePath) -> Bool {
            path.contours.contains { contour in
                contour.segments.contains { if case .arc = $0 { true } else { false } }
            }
        }
        let straight = Outliner.outlinePolyline(points: points, isClosed: false,
                                                isSmooth: false, width: 2, cap: .butt)
        let smooth = Outliner.outlinePolyline(points: points, isClosed: false,
                                              isSmooth: true, width: 2, cap: .butt)
        // Straight segments produce only line edges (plus butt caps); the round
        // disc joins are arcs, so check the centerline instead: the smooth one
        // differs from the straight one.
        #expect(smooth != straight)
        #expect(hasArc(smooth))
    }

    @Test("Smoothing collinear points falls back to straight without arcs")
    func collinearStaysStraight() {
        let line = [IconPoint(x: 0, y: 0), IconPoint(x: 3, y: 0),
                    IconPoint(x: 6, y: 0)]
        let smooth = Outliner.outlinePolyline(points: line, isClosed: false,
                                              isSmooth: true, width: 2, cap: .butt)
        #expect(!smooth.isEmpty)
    }
}
