//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
@testable import GriddyGeometry

/// Metrics chosen so that one unit is exactly 4 template units, which makes the
/// arithmetic in these tests checkable by hand.
private let metrics = TemplateMetrics(
    baselineY: 100,
    caplineY: 36,
    leftMarginX: 20,
    alignmentRects: [:]
)

@Suite("Coordinate system derivation")
struct CoordinateSystemDerivationTests {

    @Test("Cap height is the baseline-to-capline distance, sign independent")
    func capHeightIsAbsolute() {
        #expect(metrics.capHeight == 64)

        // SVG Y increases downward, so a template could plausibly be authored
        // with the guides the other way around. Cap height must not go negative.
        let inverted = TemplateMetrics(baselineY: 36,
                                       caplineY: 100,
                                       leftMarginX: 20,
                                       alignmentRects: [:])
        #expect(inverted.capHeight == 64)
    }

    @Test("One unit is a sixteenth of cap height")
    func unitIsCapHeightOverSixteen() {
        let system = CoordinateSystem(templateMetrics: metrics)
        #expect(system.unitInTemplateSpace == 4)
    }

    @Test("Canvas is 16 units tall and defaults to 16 wide")
    func canvasBounds() {
        let system = CoordinateSystem(templateMetrics: metrics)
        #expect(system.canvasBounds.size.height == 16)
        #expect(system.canvasBounds.size.width == 16)
        #expect(system.canvasBounds.origin == .zero)
    }

    @Test("Canvas width is free, so wide symbols can exceed 16 units")
    func canvasWidthIsFree() {
        let system = CoordinateSystem(templateMetrics: metrics,
                                      canvasWidthInUnits: 22)
        #expect(system.canvasBounds.size.width == 22)
        #expect(system.canvasBounds.size.height == 16,
                "Height must stay pinned to cap height regardless of width")
    }
}

@Suite("Export transform")
struct ExportTransformTests {

    private let system = CoordinateSystem(templateMetrics: metrics)

    @Test("Origin maps to the baseline at the left margin")
    func originMapsToBaseline() {
        let point = system.templatePoint(from: .zero)
        #expect(point.x == 20)
        #expect(point.y == 100)
    }

    @Test("Y is flipped, so 16u up lands on the capline")
    func yAxisIsFlipped() {
        let capline = system.templatePoint(from: IconPoint(x: 0, y: 16))
        #expect(capline.y == 36, "16u above the baseline is the capline")

        let oneUnitUp = system.templatePoint(from: IconPoint(x: 0, y: 1))
        #expect(oneUnitUp.y == 96, "Moving up in unit space decreases template Y")
    }

    @Test("Scaling is uniform across both axes")
    func scalingIsUniform() {
        let point = system.templatePoint(from: IconPoint(x: 3, y: 3))
        let dx = point.x - 20
        let dy = 100 - point.y
        #expect(dx == dy, "A shear or non-uniform scale would break this")
        #expect(dx == 12)
    }

    @Test("Round trip through template space is lossless")
    func roundTrip() {
        let originals = [
            IconPoint(x: 0, y: 0),
            IconPoint(x: 8, y: 8),
            IconPoint(x: 22.5, y: 15.25),
            IconPoint(x: -3, y: 1.125)
        ]

        for original in originals {
            let restored = system.iconPoint(from: system.templatePoint(from: original))
            #expect(abs(restored.x - original.x) < 1e-12)
            #expect(abs(restored.y - original.y) < 1e-12)
        }
    }

    @Test("Degenerate cap height does not produce NaN or infinity")
    func degenerateCapHeight() {
        let degenerate = TemplateMetrics(baselineY: 50,
                                         caplineY: 50,
                                         leftMarginX: 0,
                                         alignmentRects: [:])
        let system = CoordinateSystem(templateMetrics: degenerate)
        let point = system.iconPoint(from: IconPoint(x: 10, y: 10))
        #expect(point == .zero, "A zero-height template must not divide by zero")
    }

    @Test("Lengths scale by the unit size")
    func lengthConversion() {
        #expect(system.templateLength(from: 1) == 4)
        #expect(system.templateLength(from: 0.25) == 1)
    }
}

@Suite("Symbol slots")
struct SymbolSlotTests {

    @Test("A full export covers 27 slots")
    func slotCount() {
        #expect(SymbolSlot.all.count == 27)
        #expect(Set(SymbolSlot.all).count == 27, "Slots must be unique")
    }

    @Test("Exactly three slots are authored")
    func authoredSlots() {
        #expect(SymbolSlot.authored.count == 3)
        #expect(SymbolSlot.all.filter(\.isAuthored).count == 3)

        for slot in SymbolSlot.authored {
            #expect(slot.scale == .medium, "Authoring happens at Medium only")
        }
    }

    @Test("Weight axis positions are monotonic across the nine weights")
    func weightAxisIsMonotonic() {
        let positions = SymbolWeight.allCases.map(\.axisPosition)
        #expect(positions == positions.sorted())
    }

    @Test("Authored weights anchor the axis at 0, 1 and 2")
    func authoredWeightAnchors() {
        #expect(SymbolWeight.ultralight.axisPosition == 0)
        #expect(SymbolWeight.regular.axisPosition == 1)
        #expect(SymbolWeight.black.axisPosition == 2)
    }
}
