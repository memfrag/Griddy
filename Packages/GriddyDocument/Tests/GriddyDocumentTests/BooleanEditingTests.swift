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

/// Two overlapping circles, returned with their identifiers in draw order.
private func twoCircles() -> (SymbolDocument, PrimitiveID, PrimitiveID) {
    var document = SymbolDocument.new(name: "T",
                                      templateMetrics: metrics,
                                      appVersion: "test")
    let left = CirclePrimitive(center: IconPoint(x: 8, y: 8), radius: 4)
    let right = CirclePrimitive(center: IconPoint(x: 12, y: 8), radius: 4)
    document.addPrimitive(.circle(left))
    document.addPrimitive(.circle(right))
    return (document, left.id, right.id)
}

@Suite("Combining primitives")
struct BooleanEditingTests {

    @Test("One shape is not enough to combine")
    func refusesSingleOperand() {
        let (document, left, _) = twoCircles()
        #expect(document.canCombine([left]) == .tooFewOperands(1))
        #expect(document.canCombine([]) == .tooFewOperands(0))
    }

    @Test("Two shapes can be combined")
    func acceptsTwoOperands() {
        let (document, left, right) = twoCircles()
        #expect(document.canCombine([left, right]) == nil)
    }

    @Test("Combining leaves one visible shape where there were two")
    func combineProducesOneRoot() throws {
        var (document, left, right) = twoCircles()
        let id = try document.combinePrimitives(withIDs: [left, right],
                                                operation: .union)

        // The children stay in the document -- removing them would make undo a
        // resurrection -- but stop being drawn on their own.
        #expect(document.primitives.count == 3)
        #expect(document.primitive(withID: left) != nil)
        #expect(document.primitive(withID: right) != nil)

        let outline = document.resolvedOutline(weight: .regular)
        #expect(!outline.isEmpty)
        #expect(document.primitive(withID: id) != nil)
    }

    @Test("Union changes nothing, because roots are already unioned")
    func unionIsImplicit() throws {
        var (document, left, right) = twoCircles()
        let separate = document.resolvedOutline(weight: .regular)

        try document.combinePrimitives(withIDs: [left, right],
                                       operation: .union)

        // `resolvedOutline` unions every root primitive, so two shapes drawn
        // side by side are *already* a union. Making that explicit produces
        // exactly the same outline.
        //
        // A union compound is therefore not a drawing operation. Its use is
        // structural: it packages several shapes into one operand so an outer
        // subtract or intersect can act on them together.
        #expect(document.resolvedOutline(weight: .regular) == separate)
    }

    @Test("Subtract removes material, which union cannot")
    func subtractChangesTheDrawing() throws {
        var (document, left, right) = twoCircles()
        let separate = document.resolvedOutline(weight: .regular)

        try document.combinePrimitives(withIDs: [left, right],
                                       operation: .subtract)
        let cut = document.resolvedOutline(weight: .regular)

        // Subtract and intersect are the operations that actually need a
        // compound: neither can be expressed by placing shapes side by side.
        #expect(cut != separate)
        #expect(!cut.isEmpty)
    }

    @Test("Intersect keeps only the overlap")
    func intersectChangesTheDrawing() throws {
        var (document, left, right) = twoCircles()
        let separate = document.resolvedOutline(weight: .regular)

        try document.combinePrimitives(withIDs: [left, right],
                                       operation: .intersect)
        let overlap = document.resolvedOutline(weight: .regular)

        #expect(overlap != separate)
    }

    @Test("Subtraction takes the draw-order-first shape as the minuend")
    func subtractionOrderIsDrawOrder() throws {
        var (document, left, right) = twoCircles()
        let id = try document.combinePrimitives(withIDs: [left, right],
                                                operation: .subtract)

        // A set has no order and "the one I clicked first" is not something the
        // document knows, so draw order decides. The bottom-most shape is the
        // one subtracted *from*, which is what the canvas suggests.
        guard case .compound(let compound)? = document.primitive(withID: id) else {
            Issue.record("not a compound")
            return
        }
        #expect(compound.children == [left, right])
    }

    @Test("Releasing brings the children back")
    func releaseRestores() throws {
        var (document, left, right) = twoCircles()
        let before = document.resolvedOutline(weight: .regular)

        let id = try document.combinePrimitives(withIDs: [left, right],
                                                operation: .union)
        let released = document.releaseCompounds(withIDs: [id])

        #expect(released == [left, right])
        #expect(document.primitive(withID: id) == nil)
        #expect(document.primitives.count == 2)

        // Back to exactly what it was.
        #expect(document.resolvedOutline(weight: .regular) == before)
    }

    @Test("Releasing something that is not a compound does nothing")
    func releaseIgnoresPlainShapes() {
        var (document, left, _) = twoCircles()
        #expect(document.releaseCompounds(withIDs: [left]).isEmpty)
        #expect(document.primitives.count == 2)
    }

    @Test("A nested compound survives its outer one being released")
    func nestedRelease() throws {
        var (document, left, right) = twoCircles()
        let third = CirclePrimitive(center: IconPoint(x: 16, y: 8), radius: 4)
        document.addPrimitive(.circle(third))

        let inner = try document.combinePrimitives(withIDs: [left, right],
                                                   operation: .union)
        let outer = try document.combinePrimitives(withIDs: [inner, third.id],
                                                   operation: .subtract)

        // Releasing the outer must report the inner compound as visible again,
        // not the inner's children -- those are still claimed.
        let released = document.releaseCompounds(withIDs: [outer])
        #expect(released == [inner, third.id])
        #expect(document.primitive(withID: inner) != nil)
    }

    @Test("Compounds are detected so Release can be offered")
    func detectsCompounds() throws {
        var (document, left, right) = twoCircles()
        #expect(!document.containsCompound([left, right]))

        let id = try document.combinePrimitives(withIDs: [left, right],
                                                operation: .union)
        #expect(document.containsCompound([id]))
        #expect(document.containsCompound([id, left]))
    }
}

@Suite("Selecting and moving compounds")
struct CompoundSelectionTests {

    @Test("Clicking a combined shape selects the compound, not a child")
    func hitFindsTheCompound() throws {
        var (document, left, right) = twoCircles()
        let id = try document.combinePrimitives(withIDs: [left, right],
                                                operation: .union)

        // The children are still in the document but no longer drawn. Hit
        // testing the flat primitive list would find one of them, so clicking a
        // combined shape would select something invisible.
        let onTheLeftCircle = IconPoint(x: 4, y: 8)
        let hit = document.topmostPrimitive(at: onTheLeftCircle, tolerance: 0.5)
        #expect(hit?.id == id)
    }

    @Test("A compound has bounds covering its children")
    func compoundHasBounds() throws {
        var (document, left, right) = twoCircles()
        let id = try document.combinePrimitives(withIDs: [left, right],
                                                operation: .union)
        let compound = try #require(document.primitive(withID: id))

        // PrimitiveGeometry returns nil here: it sees one primitive at a time
        // and cannot follow child identifiers. Without bounds a compound draws
        // no selection handles and marquee selection cannot find it.
        #expect(PrimitiveGeometry.bounds(of: compound) == nil)

        let bounds = try #require(document.bounds(of: compound))
        #expect(bounds.minX <= 4)
        #expect(bounds.maxX >= 16)
    }

    @Test("Marquee selection finds the compound and not its children")
    func marqueeFindsRoots() throws {
        var (document, left, right) = twoCircles()
        let id = try document.combinePrimitives(withIDs: [left, right],
                                                operation: .union)

        let everything = IconRect(x: -50, y: -50, width: 200, height: 200)
        let picked = document.rootPrimitives(intersecting: everything)
        #expect(picked.map(\.id) == [id])
    }

    @Test("Moving a compound moves its children")
    func translateCarriesChildren() throws {
        var (document, left, right) = twoCircles()
        let id = try document.combinePrimitives(withIDs: [left, right],
                                                operation: .union)
        let before = try #require(document.primitive(withID: left))
        let beforeBounds = try #require(PrimitiveGeometry.bounds(of: before))

        // A compound holds only references, so translating the wrapper alone
        // moves nothing at all -- the shape lives entirely in the children.
        document.translateIncludingChildren(withIDs: [id],
                                            by: IconVector(dx: 3, dy: 0))

        let after = try #require(document.primitive(withID: left))
        let afterBounds = try #require(PrimitiveGeometry.bounds(of: after))
        #expect(abs(afterBounds.minX - (beforeBounds.minX + 3)) < 1e-9)
    }

    @Test("Moving a nested compound reaches the innermost children")
    func translateReachesNestedChildren() throws {
        var (document, left, right) = twoCircles()
        let third = CirclePrimitive(center: IconPoint(x: 16, y: 8), radius: 4)
        document.addPrimitive(.circle(third))

        let inner = try document.combinePrimitives(withIDs: [left, right],
                                                   operation: .union)
        let outer = try document.combinePrimitives(withIDs: [inner, third.id],
                                                   operation: .subtract)

        let originalChild = try #require(document.primitive(withID: left))
        let before = try #require(PrimitiveGeometry.bounds(of: originalChild))

        document.translateIncludingChildren(withIDs: [outer],
                                            by: IconVector(dx: 0, dy: 2))

        let movedChild = try #require(document.primitive(withID: left))
        let after = try #require(PrimitiveGeometry.bounds(of: movedChild))

        #expect(abs(after.minY - (before.minY + 2)) < 1e-9)
    }

    @Test("A compound that claims itself does not erase the artwork")
    func selfReferenceIsIgnored() {
        var (document, left, _) = twoCircles()
        let compound = CompoundPrimitive(operation: .union, children: [])
        var malformed = compound
        malformed.children = [compound.id, left]
        document.addPrimitive(.compound(malformed))

        // Letting it claim itself would drop it from the roots and silently
        // erase everything.
        #expect(!document.claimedPrimitiveIDs.contains(malformed.id))
        #expect(document.rootPrimitivesInDrawOrder.contains { $0.id == malformed.id })
    }
}
