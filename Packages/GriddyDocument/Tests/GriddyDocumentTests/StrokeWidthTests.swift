//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
import GriddyGeometry
@testable import GriddyDocument

private func document(with primitive: IconPrimitive) -> SymbolDocument {
    var document = SymbolDocument.new(name: "Test",
                                      templateMetrics: .blankTemplate,
                                      appVersion: "1.0.0")
    document.addPrimitive(primitive)
    return document
}

@Suite("Stroke width resolution")
struct StrokeWidthTests {

    @Test("System weight follows the weight propagation anchors")
    func systemWeight() {
        let circle = CirclePrimitive(center: .zero, radius: 4)
        let document = document(with: .circle(circle))
        let defaults = WeightPropagationSettings.default

        #expect(document.strokeWidth(for: .circle(circle), weight: .ultralight)
                == defaults.ultralightStrokeExpansion)
        #expect(document.strokeWidth(for: .circle(circle), weight: .regular)
                == defaults.regularStrokeExpansion)
        #expect(document.strokeWidth(for: .circle(circle), weight: .black)
                == defaults.blackStrokeExpansion)
    }

    @Test("Intermediate weights interpolate between the authored anchors")
    func intermediateWeights() {
        let circle = CirclePrimitive(center: .zero, radius: 4)
        let document = document(with: .circle(circle))

        let light = document.strokeWidth(for: .circle(circle), weight: .light)
        let regular = document.strokeWidth(for: .circle(circle), weight: .regular)
        let bold = document.strokeWidth(for: .circle(circle), weight: .bold)

        #expect(light < regular)
        #expect(regular < bold)

        // Monotonic across all nine weights, or the family reads wrong.
        let widths = SymbolWeight.allCases.map {
            document.strokeWidth(for: .circle(circle), weight: $0)
        }
        #expect(widths == widths.sorted())
    }

    @Test("A fixed width ignores the weight axis entirely")
    func fixedWidth() {
        var circle = CirclePrimitive(center: .zero, radius: 4)
        circle.attributes.stroke.width = .fixed(0.5)
        let document = document(with: .circle(circle))

        for weight in SymbolWeight.allCases {
            #expect(document.strokeWidth(for: .circle(circle), weight: weight) == 0.5)
        }
    }

    @Test("A per-master adjustment offsets the resolved width")
    func masterAdjustment() {
        let circle = CirclePrimitive(center: .zero, radius: 4)
        var document = document(with: .circle(circle))

        let blackIndex = try? #require(
            document.masters.firstIndex { $0.weight == .black })
        guard let blackIndex else {
            return
        }
        document.masters[blackIndex].setAdjustment(
            MasterAdjustment(primitiveID: circle.id, strokeWidthDelta: 0.5))

        let expected = WeightPropagationSettings.default.blackStrokeExpansion + 0.5
        #expect(document.strokeWidth(for: .circle(circle), weight: .black) == expected)

        // Other masters are untouched.
        #expect(document.strokeWidth(for: .circle(circle), weight: .regular)
                == WeightPropagationSettings.default.regularStrokeExpansion)
    }

    @Test("A negative adjustment cannot drive the width below zero")
    func clampedAtZero() {
        let circle = CirclePrimitive(center: .zero, radius: 4)
        var document = document(with: .circle(circle))

        for index in document.masters.indices {
            document.masters[index].setAdjustment(
                MasterAdjustment(primitiveID: circle.id, strokeWidthDelta: -100))
        }

        // A negative width would invert the outline at export.
        #expect(document.strokeWidth(for: .circle(circle), weight: .regular) == 0)
    }
}
