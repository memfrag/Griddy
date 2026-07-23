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

private func documentWithCircle() -> (SymbolDocument, PrimitiveID) {
    var document = SymbolDocument.new(name: "T",
                                      templateMetrics: metrics,
                                      appVersion: "test")
    let circle = CirclePrimitive(center: IconPoint(x: 8, y: 8), radius: 4)
    document.addPrimitive(.circle(circle))
    return (document, circle.id)
}

@Suite("Master geometry adjustments")
struct MasterAdjustmentTests {

    @Test("An adjustment moves the primitive in its own master only")
    func adjustmentIsPerMaster() {
        var (document, id) = documentWithCircle()
        document.setAdjustment(
            MasterAdjustment(primitiveID: id,
                             positionOffset: IconVector(dx: 3, dy: 0)),
            weight: .black)

        // Black sees the moved circle; Regular does not.
        let black = document.adjusted(
            document.primitive(withID: id)!, weight: .black)
        let regular = document.adjusted(
            document.primitive(withID: id)!, weight: .regular)

        #expect(black.anchor == IconPoint(x: 11, y: 8))
        #expect(regular.anchor == IconPoint(x: 8, y: 8))
    }

    @Test("A radius delta resizes in its master")
    func radiusDeltaApplies() {
        var (document, id) = documentWithCircle()
        document.setAdjustment(
            MasterAdjustment(primitiveID: id, radiusDelta: 2), weight: .ultralight)

        #expect(document.adjusted(
            document.primitive(withID: id)!, weight: .ultralight).radius == 6)
        #expect(document.adjusted(
            document.primitive(withID: id)!, weight: .regular).radius == 4)
    }

    @Test("A derived weight interpolates the adjustment between anchors")
    func derivedWeightInterpolates() {
        var (document, id) = documentWithCircle()
        // No offset at Regular (axis 1), +4 at Black (axis 2).
        document.setAdjustment(
            MasterAdjustment(primitiveID: id,
                             positionOffset: IconVector(dx: 4, dy: 0)),
            weight: .black)

        // Semibold sits at axis 1.4 (Regular is 1.0, Black 2.0), so t = 0.4
        // of the way from 0 to +4: 1.6.
        let semibold = document.adjustment(for: id, weight: .semibold)
        #expect(abs(semibold.positionOffset.dx - 1.6) < 1e-9)

        // The anchors stay exact.
        #expect(document.adjustment(for: id, weight: .regular).positionOffset.dx == 0)
        #expect(document.adjustment(for: id, weight: .black).positionOffset.dx == 4)
    }

    @Test("The adjustment changes the resolved outline")
    func outlineReflectsAdjustment() {
        var (document, id) = documentWithCircle()
        let before = document.resolvedOutline(weight: .black)

        document.setAdjustment(
            MasterAdjustment(primitiveID: id,
                             positionOffset: IconVector(dx: 3, dy: 0)),
            weight: .black)
        let after = document.resolvedOutline(weight: .black)

        // The whole point: a stored geometry adjustment must actually move the
        // exported artwork, not just sit in the model.
        #expect(before != after)
        // And Regular, unadjusted, is untouched.
        #expect(document.resolvedOutline(weight: .regular)
                == documentWithCircle().0.resolvedOutline(weight: .regular))
    }

    @Test("Setting an adjustment on a derived weight is ignored")
    func derivedWeightNotAdjustable() {
        var (document, id) = documentWithCircle()
        document.setAdjustment(
            MasterAdjustment(primitiveID: id,
                             positionOffset: IconVector(dx: 5, dy: 0)),
            weight: .semibold)

        // Semibold has no master, so there is nowhere to store it, and it must
        // not silently create one.
        #expect(document.adjustment(for: id, weight: .semibold).positionOffset.dx == 0)
    }
}
