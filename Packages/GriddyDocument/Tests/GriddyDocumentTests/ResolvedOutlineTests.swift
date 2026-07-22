//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
import GriddyGeometry
@testable import GriddyDocument

private func emptyDocument() -> SymbolDocument {
    SymbolDocument.new(name: "Test",
                       templateMetrics: .provisionalBlankTemplate,
                       appVersion: "1.0.0")
}

private func approximately(_ value: Double,
                           _ expected: Double,
                           tolerance: Double = 1e-6) -> Bool {
    abs(value - expected) <= tolerance
}

@Suite("Resolved document outline")
struct ResolvedOutlineTests {

    @Test("An empty document resolves to nothing")
    func emptyDocumentResolves() {
        #expect(emptyDocument().resolvedOutline(weight: .regular).isEmpty)
    }

    @Test("A single primitive resolves to its own outline")
    func singlePrimitive() {
        var document = emptyDocument()
        let circle = CirclePrimitive(center: IconPoint(x: 8, y: 8), radius: 4)
        document.addPrimitive(.circle(circle))

        let resolved = document.resolvedOutline(weight: .regular)
        let width = document.strokeWidth(for: .circle(circle), weight: .regular)

        #expect(approximately(resolved.area, 2 * .pi * 4 * width))
    }

    @Test("Overlapping primitives union rather than double count")
    func overlappingPrimitivesUnion() {
        var document = emptyDocument()
        let first = CirclePrimitive(center: IconPoint(x: 6, y: 8), radius: 3)
        let second = CirclePrimitive(center: IconPoint(x: 9, y: 8), radius: 3)
        document.addPrimitive(.circle(first))
        document.addPrimitive(.circle(second))

        let resolved = document.resolvedOutline(weight: .regular)

        let width = document.strokeWidth(for: .circle(first), weight: .regular)
        let separate = 2 * (2 * .pi * 3 * width)

        #expect(resolved.area < separate, "the overlap is counted once")
        #expect(resolved.area > separate / 2)
    }

    @Test("Hidden primitives are excluded")
    func hiddenExcluded() {
        var document = emptyDocument()
        var circle = CirclePrimitive(center: IconPoint(x: 8, y: 8), radius: 4)
        circle.attributes.isVisible = false
        document.addPrimitive(.circle(circle))

        #expect(document.resolvedOutline(weight: .regular).isEmpty)
    }

    @Test("Primitives excluded from export do not contribute")
    func nonExportingExcluded() {
        var document = emptyDocument()
        var circle = CirclePrimitive(center: IconPoint(x: 8, y: 8), radius: 4)
        circle.attributes.participatesInExport = false
        document.addPrimitive(.circle(circle))

        #expect(document.resolvedOutline(weight: .regular).isEmpty)
    }

    @Test("Heavier weights resolve to more area")
    func weightAffectsArea() {
        var document = emptyDocument()
        document.addPrimitive(.circle(
            CirclePrimitive(center: IconPoint(x: 8, y: 8), radius: 4)))

        let ultralight = document.resolvedOutline(weight: .ultralight).area
        let regular = document.resolvedOutline(weight: .regular).area
        let black = document.resolvedOutline(weight: .black).area

        #expect(ultralight < regular)
        #expect(regular < black)
    }

    @Test("A compound subtracts one child from another")
    func compoundSubtract() throws {
        var document = emptyDocument()

        // Both operands are stroked, so each is a ring rather than a solid.
        // They must overlap for a subtraction to remove anything: a small ring
        // sitting in the empty middle of a larger one takes nothing away.
        let target = CirclePrimitive(center: IconPoint(x: 6, y: 8), radius: 3)
        let cutter = CirclePrimitive(center: IconPoint(x: 9, y: 8), radius: 3)
        document.addPrimitive(.circle(target))
        document.addPrimitive(.circle(cutter))

        let targetAlone = try #require(document.outline(for: .circle(target),
                                                        weight: .regular,
                                                        visiting: []))

        document.addPrimitive(.compound(CompoundPrimitive(
            operation: .subtract, children: [target.id, cutter.id])))

        let resolved = document.resolvedOutline(weight: .regular)

        #expect(!resolved.isEmpty)
        #expect(resolved.area < targetAlone.area,
                "the overlapping cutter should remove area")
    }

    @Test("A compound's children do not also contribute on their own")
    func childrenNotDoubleCounted() {
        var document = emptyDocument()

        let first = CirclePrimitive(center: IconPoint(x: 6, y: 8), radius: 3)
        let second = CirclePrimitive(center: IconPoint(x: 9, y: 8), radius: 3)
        document.addPrimitive(.circle(first))
        document.addPrimitive(.circle(second))

        let withoutCompound = document.resolvedOutline(weight: .regular).area

        document.addPrimitive(.compound(CompoundPrimitive(
            operation: .union, children: [first.id, second.id])))
        let withCompound = document.resolvedOutline(weight: .regular).area

        // A union compound over the same two circles is the same region the
        // document already resolved to; the children must not be added twice.
        #expect(approximately(withCompound, withoutCompound, tolerance: 1e-6))
    }

    @Test("A compound that reaches itself resolves to nothing, not a crash")
    func selfReferencingCompound() {
        var document = emptyDocument()

        let circle = CirclePrimitive(center: IconPoint(x: 8, y: 8), radius: 3)
        document.addPrimitive(.circle(circle))

        let id = PrimitiveID()
        let cyclic = CompoundPrimitive(id: id,
                                       operation: .union,
                                       children: [circle.id, id])
        document.addPrimitive(.compound(cyclic))

        // The guard is what keeps this from recursing until the stack runs out.
        let resolved = document.resolvedOutline(weight: .regular)
        #expect(!resolved.isEmpty, "the non-cyclic child still contributes")
    }

    @Test("A compound referencing a missing primitive is tolerated")
    func danglingChild() {
        var document = emptyDocument()
        let circle = CirclePrimitive(center: IconPoint(x: 8, y: 8), radius: 3)
        document.addPrimitive(.circle(circle))
        document.addPrimitive(.compound(CompoundPrimitive(
            operation: .union, children: [circle.id, PrimitiveID()])))

        #expect(!document.resolvedOutline(weight: .regular).isEmpty)
    }
}
