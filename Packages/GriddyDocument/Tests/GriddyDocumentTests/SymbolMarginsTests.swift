//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
import GriddyGeometry
@testable import GriddyDocument

private let system = CoordinateSystem(templateMetrics: TemplateMetrics(
    baselineY: 100, caplineY: 36, leftMarginX: 20, rightMarginX: 116,
    alignmentRects: [:]))

@Suite("Symbol margins")
struct SymbolMarginsTests {

    @Test("An empty document centres its guides in the design area")
    func emptyIsCentred() {
        let resolved = ResolvedMargins.resolve(outline: OutlinePath(contours: []),
                                               weight: .regular,
                                               margins: SymbolMargins(),
                                               coordinateSystem: system)

        // Placed at the origin these landed at 17%-50% of the canvas, because
        // the design area is asymmetric about x = 0 by design.
        let centre = system.designArea.center.x
        #expect(resolved.originX + resolved.advance / 2 == centre)
        #expect(resolved.advance == ResolvedMargins.emptyAdvanceInUnits)
    }

    @Test("Guides hug the artwork as soon as there is any")
    func adaptsToArtwork() {
        var document = SymbolDocument.new(name: "T",
                                          templateMetrics: system.templateMetrics,
                                          appVersion: "1.0")
        document.addPrimitive(.circle(
            CirclePrimitive(center: IconPoint(x: 20, y: 8), radius: 3)))

        let resolved = ResolvedMargins.resolve(
            outline: document.resolvedOutline(weight: .regular),
            weight: .regular,
            margins: document.margins,
            coordinateSystem: system)

        let bounds = try! #require(document.resolvedOutline(weight: .regular).bounds)
        let bearing = system.standardSideBearing

        #expect(abs(resolved.originX - (bounds.minX - bearing)) < 1e-9)
        #expect(abs(resolved.advance
                    - (bounds.size.width + bearing * 2)) < 1e-9)
    }

    @Test("An override replaces the standard bearing for that weight only")
    func overridesArePerWeight() {
        var margins = SymbolMargins()
        margins.override(GlyphMetrics(leftSideBearing: 1, rightSideBearing: 0.5),
                         for: .black)

        // Apple does exactly this: takeoutbag.and.cup.and.straw carries right
        // bearings of 6.67, 4.09 and 2.36 where the standard is 9.77.
        #expect(margins.metrics(for: .black, in: system).rightSideBearing == 0.5)
        #expect(margins.metrics(for: .regular, in: system).rightSideBearing
                == system.standardSideBearing)
        #expect(!margins.isAutomatic)

        margins.clearOverride(for: .black)
        #expect(margins.isAutomatic)
    }
}
