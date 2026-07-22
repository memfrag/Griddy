//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
import GriddyGeometry
import GriddyConstraints
@testable import GriddyDocument

private func emptyDocument() -> SymbolDocument {
    SymbolDocument.new(name: "Test",
                       templateMetrics: .provisionalBlankTemplate,
                       appVersion: "1.0.0")
}

@Suite("Adding primitives")
struct AddPrimitiveTests {

    @Test("A new primitive joins the document and a layer")
    func addsToLayer() throws {
        var document = emptyDocument()
        let circle = CirclePrimitive(center: IconPoint(x: 8, y: 8), radius: 4)

        document.addPrimitive(.circle(circle))

        #expect(document.primitives.count == 1)
        let layer = try #require(document.layer(containing: circle.id))
        #expect(layer.primitiveIDs == [circle.id])

        // A primitive that no layer claims would never render.
        #expect(document.orphanedPrimitiveIDs.isEmpty)
        #expect(document.danglingPrimitiveIDs.isEmpty)
    }

    @Test("Adding to a named layer puts it there")
    func addsToNamedLayer() throws {
        var document = emptyDocument()
        let detail = SymbolLayer(name: "Detail", role: .detail)
        document.layers.append(detail)

        let line = LinePrimitive(start: .zero, end: IconPoint(x: 4, y: 4))
        document.addPrimitive(.line(line), toLayerWithID: detail.id)

        #expect(document.layer(containing: line.id)?.id == detail.id)
    }

    @Test("An unknown layer falls back rather than losing the primitive")
    func unknownLayerFallsBack() {
        var document = emptyDocument()
        let line = LinePrimitive(start: .zero, end: IconPoint(x: 4, y: 4))

        document.addPrimitive(.line(line), toLayerWithID: UUID())

        #expect(document.orphanedPrimitiveIDs.isEmpty,
                "A bad layer id must not strand the primitive")
    }

    @Test("A document with no layers gains one")
    func createsLayerWhenNoneExist() {
        var document = emptyDocument()
        document.layers = []

        let line = LinePrimitive(start: .zero, end: IconPoint(x: 4, y: 4))
        document.addPrimitive(.line(line))

        #expect(document.layers.count == 1)
        #expect(document.orphanedPrimitiveIDs.isEmpty)
    }
}

@Suite("Removing primitives")
struct RemovePrimitiveTests {

    @Test("Removal clears the primitive and its layer membership")
    func removesEverywhere() {
        var document = emptyDocument()
        let circle = CirclePrimitive(center: IconPoint(x: 8, y: 8), radius: 4)
        document.addPrimitive(.circle(circle))

        document.removePrimitives(withIDs: [circle.id])

        #expect(document.primitives.isEmpty)
        #expect(document.danglingPrimitiveIDs.isEmpty,
                "A layer must not keep pointing at a deleted primitive")
    }

    @Test("Removal drops constraints that governed the primitive")
    func removesConstraints() {
        var document = emptyDocument()
        let circle = CirclePrimitive(center: IconPoint(x: 8, y: 8), radius: 4)
        let line = LinePrimitive(start: .zero, end: IconPoint(x: 4, y: 4))
        document.addPrimitive(.circle(circle))
        document.addPrimitive(.line(line))

        document.constraints = [
            .centered(CenteredConstraint(primitiveID: circle.id, axis: .horizontal)),
            .tangent(TangentConstraint(primitiveID: line.id,
                                       targetPrimitiveID: circle.id)),
            .centered(CenteredConstraint(primitiveID: line.id, axis: .vertical))
        ]

        document.removePrimitives(withIDs: [circle.id])

        // Both constraints referencing the circle go, including the tangent
        // that only mentioned it as a target. A constraint pointing at absent
        // geometry can never be satisfied.
        #expect(document.constraints.count == 1)
        #expect(document.constraints.first?.affectedPrimitiveIDs == [line.id])
    }

    @Test("Removal drops per-master adjustments")
    func removesAdjustments() {
        var document = emptyDocument()
        let circle = CirclePrimitive(center: IconPoint(x: 8, y: 8), radius: 4)
        document.addPrimitive(.circle(circle))

        for index in document.masters.indices {
            document.masters[index].setAdjustment(
                MasterAdjustment(primitiveID: circle.id, strokeWidthDelta: 0.2))
        }

        document.removePrimitives(withIDs: [circle.id])

        #expect(document.masters.allSatisfy { $0.adjustments.isEmpty })
    }

    @Test("Removing nothing changes nothing")
    func removingEmptySetIsANoOp() {
        var document = emptyDocument()
        document.addPrimitive(.circle(CirclePrimitive(center: .zero, radius: 1)))
        let before = document

        document.removePrimitives(withIDs: [])

        #expect(document == before)
    }
}

@Suite("Moving and replacing")
struct MoveReplaceTests {

    @Test("Translation moves only the selected primitives")
    func translatesSelection() throws {
        var document = emptyDocument()
        let moved = CirclePrimitive(center: IconPoint(x: 4, y: 4), radius: 1)
        let stationary = CirclePrimitive(center: IconPoint(x: 10, y: 10), radius: 1)
        document.addPrimitive(.circle(moved))
        document.addPrimitive(.circle(stationary))

        document.translatePrimitives(withIDs: [moved.id],
                                     by: IconVector(dx: 2, dy: -1))

        guard case .circle(let movedAfter) =
                try #require(document.primitive(withID: moved.id)) else {
            Issue.record("Expected a circle")
            return
        }
        guard case .circle(let stationaryAfter) =
                try #require(document.primitive(withID: stationary.id)) else {
            Issue.record("Expected a circle")
            return
        }

        #expect(movedAfter.center == IconPoint(x: 6, y: 3))
        #expect(stationaryAfter.center == IconPoint(x: 10, y: 10))
    }

    @Test("Replacing keeps the primitive's place in draw order")
    func replaceKeepsOrder() throws {
        var document = emptyDocument()
        let first = CirclePrimitive(center: IconPoint(x: 2, y: 2), radius: 1)
        let second = CirclePrimitive(center: IconPoint(x: 6, y: 6), radius: 1)
        document.addPrimitive(.circle(first))
        document.addPrimitive(.circle(second))

        var edited = first
        edited.radius = 3
        document.replacePrimitive(.circle(edited))

        #expect(document.primitives.map(\.id) == [first.id, second.id],
                "An edited primitive must not jump to the front")

        guard case .circle(let restored) =
                try #require(document.primitive(withID: first.id)) else {
            Issue.record("Expected a circle")
            return
        }
        #expect(restored.radius == 3)
    }

    @Test("Replacing an unknown primitive is a no-op")
    func replaceUnknownIsANoOp() {
        var document = emptyDocument()
        let before = document

        document.replacePrimitive(.circle(CirclePrimitive(center: .zero, radius: 1)))

        #expect(document == before)
    }
}

@Suite("Draw order")
struct DrawOrderTests {

    @Test("Draw order follows layers, not storage order")
    func followsLayers() {
        var document = emptyDocument()
        document.layers = []

        let back = SymbolLayer(name: "Back", role: .outerBody)
        let front = SymbolLayer(name: "Front", role: .detail)
        document.layers = [back, front]

        let inFront = CirclePrimitive(center: .zero, radius: 1)
        let inBack = CirclePrimitive(center: .zero, radius: 2)

        // Deliberately add the front-layer primitive to storage first, so
        // storage order and draw order disagree.
        document.addPrimitive(.circle(inFront), toLayerWithID: front.id)
        document.addPrimitive(.circle(inBack), toLayerWithID: back.id)

        #expect(document.primitives.map(\.id) == [inFront.id, inBack.id])
        #expect(document.primitivesInDrawOrder.map(\.id) == [inBack.id, inFront.id])
    }

    @Test("Hidden layers are excluded from draw order")
    func hiddenLayersExcluded() {
        var document = emptyDocument()
        let circle = CirclePrimitive(center: .zero, radius: 1)
        document.addPrimitive(.circle(circle))

        document.layers[0].isVisible = false

        #expect(document.primitivesInDrawOrder.isEmpty)
    }

    @Test("Locked layers block editing but still draw")
    func lockedLayers() {
        var document = emptyDocument()
        let circle = CirclePrimitive(center: .zero, radius: 1)
        document.addPrimitive(.circle(circle))

        document.layers[0].isLocked = true

        #expect(document.primitivesInDrawOrder.count == 1)
        #expect(!document.isEditable(circle.id))
    }
}
