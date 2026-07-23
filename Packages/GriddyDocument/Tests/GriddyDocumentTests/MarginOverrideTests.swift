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

/// The read/write logic the inspector's bearing fields depend on. Verifying it
/// here rather than through the view keeps the tricky part -- overriding one
/// bearing without zeroing the other -- covered.
@Suite("Margin overrides")
struct MarginOverrideTests {

    @Test("An un-overridden weight reads the standard bearing")
    func defaultsToStandard() {
        let margins = SymbolMargins()
        let metrics = margins.metrics(for: .regular, in: system)
        #expect(metrics.leftSideBearing == system.standardSideBearing)
        #expect(metrics.rightSideBearing == system.standardSideBearing)
    }

    @Test("Overriding one bearing seeds the other from its effective value")
    func overrideKeepsTheOtherBearing() {
        var margins = SymbolMargins()

        // The inspector's set: read the current effective metrics, change one
        // field, write both. The right bearing must survive at its standard
        // value rather than dropping to zero.
        let current = margins.metrics(for: .black, in: system)
        margins.override(GlyphMetrics(leftSideBearing: 3,
                                      rightSideBearing: current.rightSideBearing),
                         for: .black)

        let after = margins.metrics(for: .black, in: system)
        #expect(after.leftSideBearing == 3)
        #expect(after.rightSideBearing == system.standardSideBearing)
    }

    @Test("An override affects only its own weight")
    func overrideIsPerWeight() {
        var margins = SymbolMargins()
        margins.override(GlyphMetrics(leftSideBearing: 1, rightSideBearing: 1),
                         for: .black)

        #expect(margins.overrides[.regular] == nil)
        #expect(margins.metrics(for: .regular, in: system).leftSideBearing
                == system.standardSideBearing)
    }

    @Test("Resetting returns the weight to computed metrics")
    func resetClearsOverride() {
        var margins = SymbolMargins()
        margins.override(GlyphMetrics(leftSideBearing: 1, rightSideBearing: 1),
                         for: .black)
        #expect(!margins.isAutomatic)

        margins.clearOverride(for: .black)
        #expect(margins.isAutomatic)
        #expect(margins.metrics(for: .black, in: system).leftSideBearing
                == system.standardSideBearing)
    }

    @Test("The advance still follows the artwork when only bearings are fixed")
    func advanceFollowsArtworkUnderOverride() {
        var document = SymbolDocument.new(name: "T",
                                          templateMetrics: system.templateMetrics,
                                          appVersion: "test")
        document.addPrimitive(.circle(
            CirclePrimitive(center: IconPoint(x: 12, y: 8), radius: 4)))
        document.margins.override(
            GlyphMetrics(leftSideBearing: 2, rightSideBearing: 2), for: .regular)

        let narrow = ResolvedMargins.resolve(
            outline: document.resolvedOutline(weight: .regular),
            weight: .regular, margins: document.margins,
            coordinateSystem: system)

        document.addPrimitive(.circle(
            CirclePrimitive(center: IconPoint(x: 20, y: 8), radius: 4)))
        let wide = ResolvedMargins.resolve(
            outline: document.resolvedOutline(weight: .regular),
            weight: .regular, margins: document.margins,
            coordinateSystem: system)

        // Fixing the bearings pins the padding, not the width: a wider drawing
        // still claims more room.
        #expect(wide.advance > narrow.advance + 3)
    }
}
