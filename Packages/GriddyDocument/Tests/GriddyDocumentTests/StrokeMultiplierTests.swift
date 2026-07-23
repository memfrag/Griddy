//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
import GriddyGeometry
@testable import GriddyDocument

private let metrics = TemplateMetrics(baselineY: 100, caplineY: 36,
                                      leftMarginX: 20, rightMarginX: 116,
                                      alignmentRects: [:])

private func document(multiplier: Double) -> (SymbolDocument, IconPrimitive) {
    var document = SymbolDocument.new(name: "T",
                                      templateMetrics: metrics,
                                      appVersion: "test")
    var circle = CirclePrimitive(center: IconPoint(x: 8, y: 8), radius: 4)
    circle.attributes.stroke.widthMultiplier = multiplier
    let primitive = IconPrimitive.circle(circle)
    document.addPrimitive(primitive)
    return (document, primitive)
}

@Suite("Per-shape stroke multiplier")
struct StrokeMultiplierTests {

    @Test("A multiplier scales the resolved width")
    func scalesWidth() {
        let (plain, p1) = document(multiplier: 1)
        let (wide, p2) = document(multiplier: 2)

        let base = plain.strokeWidth(for: p1, weight: .regular)
        let scaled = wide.strokeWidth(for: p2, weight: .regular)
        #expect(abs(scaled - base * 2) < 1e-9)
    }

    @Test("The multiplier holds across weights")
    func holdsAcrossWeights() {
        let (wide, p) = document(multiplier: 1.5)
        let (plain, q) = document(multiplier: 1)

        // A wider shape stays 1.5x at Ultralight and at Black, rather than
        // becoming a fixed thickness that stops tracking the master.
        for weight in [SymbolWeight.ultralight, .black] {
            let scaled = wide.strokeWidth(for: p, weight: weight)
            let base = plain.strokeWidth(for: q, weight: weight)
            #expect(abs(scaled - base * 1.5) < 1e-9, "\(weight.rawValue)")
        }
    }

    @Test("A wider stroke makes a heavier outline")
    func widerOutlineHasMoreArea() {
        let (plain, _) = document(multiplier: 1)
        let (wide, _) = document(multiplier: 2)

        let thin = plain.resolvedOutline(weight: .regular)
        let thick = wide.resolvedOutline(weight: .regular)
        // A circle outlined at twice the stroke is a fatter annulus.
        #expect(thick != thin)
        #expect(!thick.isEmpty)
    }

    @Test("Documents without the field decode to a multiplier of one")
    func legacyDecodesToOne() throws {
        // A stroke JSON from before the multiplier existed.
        let legacy = """
            {"width":{"systemWeight":{}},"lineCap":"round",
             "lineJoin":"round","miterLimit":10}
            """
        let stroke = try JSONDecoder().decode(
            StrokeStyleDefinition.self, from: Data(legacy.utf8))
        #expect(stroke.widthMultiplier == 1)
    }
}
