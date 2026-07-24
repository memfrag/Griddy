//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
import GriddyGeometry
@testable import GriddyDocument

@Suite("Configurable snapping")
struct SnapConfigTests {

    private func grid(snaps: Bool = true, divisions: Int = 4,
                      tolerance: Double = 0.125) -> GridDefinition {
        GridDefinition(canvasSize: IconSize(width: 48, height: 32),
                       secondaryDivisions: divisions,
                       snapsToGrid: snaps,
                       snapTolerance: tolerance)
    }

    @Test("Snapping off leaves points untouched")
    func offIsFree() {
        let g = grid(snaps: false)
        #expect(g.snapped(3.37) == 3.37)
        #expect(g.snapped(IconPoint(x: 1.1, y: 2.2)) == IconPoint(x: 1.1, y: 2.2))
    }

    @Test("Snapping on rounds to the secondary interval")
    func onSnapsToStep() {
        // 4 divisions of 1u = 0.25u step. 3.37 -> 3.25 (within 0.125).
        let g = grid(divisions: 4)
        #expect(abs(g.snapped(3.37) - 3.25) < 1e-9)
    }

    @Test("Fewer subdivisions make a coarser snap step")
    func coarserStep() {
        // 2 divisions = 0.5u step, tolerance half the step so it always snaps.
        let g = grid(divisions: 2, tolerance: 0.25)
        #expect(abs(g.snapped(1.3) - 1.5) < 1e-9)
        #expect(abs(g.snapped(1.1) - 1.0) < 1e-9)
    }

    @Test("A small tolerance is magnetic, snapping only near a line")
    func magneticTolerance() {
        // 0.25u step, tolerance 0.05: 3.26 sticks to 3.25, 3.4 stays free.
        let g = grid(divisions: 4, tolerance: 0.05)
        #expect(abs(g.snapped(3.26) - 3.25) < 1e-9)
        #expect(g.snapped(3.4) == 3.4)
    }

    @Test("Documents predating the toggle still snap")
    func legacyDefaultsToOn() throws {
        // No snapsToGrid key, and the old showsPrimaryGrid/Secondary shape.
        let legacy = """
            {"canvasSize":{"width":48,"height":32},"primaryInterval":1,
             "secondaryDivisions":4,"snapTolerance":0.125,
             "showsPrimaryGrid":true,"showsSecondaryGrid":true}
            """
        let decoded = try JSONDecoder().decode(
            GridDefinition.self, from: Data(legacy.utf8))
        #expect(decoded.snapsToGrid)
    }
}
