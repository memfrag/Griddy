//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
import GriddyGeometry
import GriddyDocument
@testable import GriddyValidation

@Suite("Export gate")
struct ExportGateTests {

    /// What the export command computes before writing.
    private func blocking(in document: SymbolDocument) -> [ValidationIssue] {
        (StructuralValidator.issues(in: document)
            + GeometricValidator.issues(in: document))
            .filter(\.severity.blocksExport)
    }

    @Test("An ordinary document does not trip the gate")
    func ordinaryExports() {
        var document = blankDocument()
        document.addPrimitive(.circle(
            CirclePrimitive(center: IconPoint(x: 12, y: 8), radius: 4)))

        let issues = blocking(in: document)
        #expect(issues.isEmpty, "\(issues.map(\.message))")
    }

    @Test("A blank document does not trip the gate")
    func blankExports() {
        // Exporting an empty symbol is pointless but not an error, and the
        // warning would fire constantly on new documents.
        #expect(blocking(in: blankDocument()).isEmpty)
    }

    @Test("Only errors block, warnings do not")
    func warningsDoNotBlock() {
        var document = blankDocument()
        document.addPrimitive(.circle(
            CirclePrimitive(center: IconPoint(x: 12, y: 8), radius: 4)))
        // Off-canvas artwork is a warning: it still exports.
        document.addPrimitive(.circle(
            CirclePrimitive(center: IconPoint(x: 900, y: 900), radius: 2)))

        let all = StructuralValidator.issues(in: document)
        #expect(all.contains { $0.severity == .warning })
        #expect(blocking(in: document).isEmpty)
    }

    @Test("A broken layer reference blocks")
    func brokenReferenceBlocks() {
        var document = blankDocument()
        document.addPrimitive(.circle(
            CirclePrimitive(center: IconPoint(x: 12, y: 8), radius: 4)))
        document.layers = []

        #expect(!blocking(in: document).isEmpty)
    }
}
