//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
import GriddyGeometry
@testable import GriddyDocument

@Suite("Guide visibility")
struct GuideSetTests {

    private var grid: GridDefinition {
        GridDefinition(canvasSize: IconSize(width: 16, height: 32),
                       safeArea: IconRect(x: 1, y: 1, width: 14, height: 14))
    }

    @Test("The default shows four guides, not all six")
    func defaultIsRestrained() {
        // Key shapes and the safe area are advisory; showing everything at once
        // is what made the canvas unreadable.
        #expect(GuideSet.default.contains(.primaryGrid))
        #expect(GuideSet.default.contains(.baseline))
        #expect(GuideSet.default.contains(.margins))
        #expect(!GuideSet.default.contains(.keyShapes))
        #expect(!GuideSet.default.contains(.safeArea))
    }

    @Test("Every guide is listed in the menu")
    func menuIsComplete() {
        // Guards against adding a guide the user cannot turn off.
        let listed = GuideSet.ordered.reduce(into: GuideSet()) {
            $0.insert($1.guide)
        }
        #expect(listed == .all)
        #expect(GuideSet.ordered.count == 6)
    }

    @Test("The grid flags still read and write through to the set")
    func legacyFlagsBridge() {
        var grid = grid
        grid.showsPrimaryGrid = false
        #expect(!grid.visibleGuides.contains(.primaryGrid))
        #expect(grid.visibleGuides.contains(.secondaryGrid))

        grid.showsPrimaryGrid = true
        #expect(grid.visibleGuides.contains(.primaryGrid))
    }

    @Test("A guide set survives a round trip")
    func roundTrips() throws {
        var grid = grid
        grid.visibleGuides = [.keyShapes, .margins]

        let data = try JSONEncoder().encode(grid)
        let back = try JSONDecoder().decode(GridDefinition.self, from: data)
        #expect(back.visibleGuides == [.keyShapes, .margins])
    }

    @Test("Documents written before guides were a set still open")
    func decodesLegacyFlags() throws {
        // The old shape: two booleans and no visibleGuides key.
        let legacy = """
            {"canvasSize":{"width":16,"height":32},
             "safeArea":{"origin":{"x":1,"y":1},"size":{"width":14,"height":14}},
             "primaryInterval":1,"secondaryDivisions":4,"snapTolerance":0.125,
             "showsPrimaryGrid":true,"showsSecondaryGrid":false}
            """
        let decoded = try JSONDecoder().decode(
            GridDefinition.self, from: Data(legacy.utf8))

        #expect(decoded.showsPrimaryGrid)
        #expect(!decoded.showsSecondaryGrid)
        // The four guides the old format knew nothing about take their default.
        #expect(decoded.visibleGuides.contains(.baseline))
        #expect(!decoded.visibleGuides.contains(.keyShapes))
    }
}
