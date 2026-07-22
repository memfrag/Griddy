//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
import GriddyGeometry
import GriddyDocument
import GriddyConstraints
@testable import GriddyValidation

/// Metrics chosen so one unit is exactly 4 template units.
let testMetrics = TemplateMetrics(baselineY: 100, caplineY: 36,
                                  leftMarginX: 20, rightMarginX: 116,
                                  alignmentRects: [:])

func blankDocument() -> SymbolDocument {
    SymbolDocument.new(name: "Test",
                       templateMetrics: testMetrics,
                       appVersion: "test")
}

@Suite("Structural validation")
struct StructuralValidatorTests {

    @Test("A blank document reports nothing")
    func blankIsClean() {
        #expect(StructuralValidator.issues(in: blankDocument()).isEmpty)
    }

    @Test("An ordinary drawing reports nothing")
    func ordinaryIsClean() {
        var document = blankDocument()
        document.addPrimitive(.circle(
            CirclePrimitive(center: IconPoint(x: 12, y: 8), radius: 4)))
        document.addPrimitive(.line(LinePrimitive(
            start: IconPoint(x: 2, y: 2), end: IconPoint(x: 10, y: 10))))

        // Guards against a validator that cries wolf, which would be worse than
        // the unconditional "No issues" it replaces.
        #expect(StructuralValidator.issues(in: document).isEmpty)
    }

    @Test("A zero-radius circle is caught")
    func zeroRadiusCircle() {
        var document = blankDocument()
        document.addPrimitive(.circle(
            CirclePrimitive(center: IconPoint(x: 8, y: 8), radius: 0)))

        let issues = StructuralValidator.degenerateGeometry(in: document)
        #expect(issues.count == 1)
        #expect(issues.first?.severity == .warning)
        #expect(issues.first?.message.contains("no radius") == true)
    }

    @Test("A zero-length line is caught")
    func zeroLengthLine() {
        var document = blankDocument()
        let point = IconPoint(x: 5, y: 5)
        document.addPrimitive(.line(LinePrimitive(start: point, end: point)))

        let issues = StructuralValidator.degenerateGeometry(in: document)
        #expect(issues.count == 1)
        #expect(issues.first?.message.contains("no length") == true)
    }

    @Test("An issue names the primitive it is about")
    func issuesAreAttributed() {
        var document = blankDocument()
        document.addPrimitive(.circle(
            CirclePrimitive(center: .zero, radius: 0)))
        let id = document.primitivesInDrawOrder.first?.id

        // Without this the strip can report a problem the user cannot locate.
        let issue = StructuralValidator.degenerateGeometry(in: document).first
        #expect(issue?.affectedPrimitiveIDs == [id].compactMap { $0 })
    }

    @Test("Artwork off the design area is flagged, not blocked")
    func strayArtwork() {
        var document = blankDocument()
        document.addPrimitive(.circle(
            CirclePrimitive(center: IconPoint(x: 500, y: 500), radius: 2)))

        let issues = StructuralValidator.placement(in: document)
        #expect(issues.count == 1)
        // A warning, not an error: it still exports, and refusing would be
        // presumptuous about a canvas that is itself a generous default.
        #expect(issues.first?.severity == .warning)
    }

    @Test("Artwork merely overhanging the canvas is not flagged")
    func overhangIsFine() {
        var document = blankDocument()
        // Straddling the left edge: partly outside, which is legitimate.
        document.addPrimitive(.circle(
            CirclePrimitive(center: IconPoint(x: -8, y: 8), radius: 4)))

        #expect(StructuralValidator.placement(in: document).isEmpty)
    }
}

private func onKeyShape() -> OnKeyShapeConstraint {
    OnKeyShapeConstraint(primitiveID: PrimitiveID(),
                         keyShapeID: UUID(),
                         overshoot: 0)
}

@Suite("Unenforced constraints")
struct UnenforcedConstraintTests {

    @Test("The five unenforced kinds are known to be unenforced")
    func unenforcedKinds() {
        // Mirrors the switch in ConstraintSolver.resolve that ignores them.
        // If someone implements one, both must change together.
        #expect(!Constraint.onKeyShape(onKeyShape()).isEnforced)
        #expect(!Constraint.equalLength(EqualLengthConstraint(
            primitiveIDs: [])).isEnforced)
        #expect(!Constraint.equalSpacing(EqualSpacingConstraint(
            primitiveIDs: [], axis: .horizontal)).isEnforced)

        // And the ones that do work still say so.
        #expect(Constraint.centered(CenteredConstraint(
            primitiveID: PrimitiveID(), axis: .horizontal)).isEnforced)
    }

    @Test("A stored but unenforced constraint is reported")
    func reportsUnenforced() {
        var document = blankDocument()
        document.constraints = [.onKeyShape(onKeyShape())]

        // The inspector adds these happily and they then move no geometry. A
        // document that silently means less than it claims is worse than one
        // that admits the gap.
        let issues = StructuralValidator.unenforcedConstraints(in: document)
        #expect(issues.count == 1)
        #expect(issues.first?.severity == .warning)
        #expect(issues.first?.message.contains("not enforced") == true)
    }

    @Test("An enforced constraint is not reported")
    func silentOnEnforced() {
        var document = blankDocument()
        document.constraints = [.centered(CenteredConstraint(
            primitiveID: PrimitiveID(), axis: .horizontal))]
        #expect(StructuralValidator.unenforcedConstraints(in: document).isEmpty)
    }
}
