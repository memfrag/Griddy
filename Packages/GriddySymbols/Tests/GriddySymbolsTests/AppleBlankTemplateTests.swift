//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
import GriddyGeometry
import GriddyDocument
@testable import GriddySymbols

/// The blank template a new document is built from must work in both dialects:
/// the one it used to be (Sketch-processed) and the pristine Apple one it now
/// is. See spec 14.2 and the provenance note in 14.5.
@Suite("Apple-dialect blank template")
struct AppleBlankTemplateTests {

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(
            forResource: "Fixtures/\(name)", withExtension: "svg"))
        return try Data(contentsOf: url)
    }

    @Test("The Apple-dialect blank imports as an empty document")
    func importsEmpty() throws {
        let package = try SFSymbolTemplateImporter.importDocument(
            try fixture("blank-template-apple-v7"), appVersion: "1.0.0")

        // A blank has no artwork, and its name comes from nowhere in the file,
        // so it falls back rather than picking up template furniture.
        #expect(package.document.primitives.isEmpty)
        #expect(package.document.metadata.name == "Untitled")

        // Metrics still come off the guides, which the Apple dialect carries.
        let system = package.document.coordinateSystem
        #expect(system.templateMetrics.capHeight > 60)
        #expect(system.unitInTemplateSpace > 0)
    }

    @Test("A symbol drawn on it exports and reimports interpolatably")
    func drawnSymbolExports() throws {
        var package = try SFSymbolTemplateImporter.importDocument(
            try fixture("blank-template-apple-v7"), appVersion: "1.0.0")
        package.document.layers = [SymbolLayer(name: "Body", role: .outerBody)]

        let centre = package.document.coordinateSystem.capHeightBox.center
        package.document.addPrimitive(.circle(
            CirclePrimitive(center: centre, radius: 5)))

        // The verified export path was proven against the Sketch dialect. This
        // proves it holds for the Apple dialect too, which is what the blank
        // now is.
        let (data, _) = try SFSymbolTemplateExporter.export(
            document: package.document, sourceTemplate: package.sourceTemplate)
        let reimported = try SFSymbolTemplateImporter.import(data)

        #expect(reimported.variants.count == 3)
        func kinds(_ w: SymbolWeight) -> [String] {
            (reimported.variants[SymbolSlot(weight: w, scale: .small)]?
                .commands ?? []).map { c in
                switch c {
                case .move: "M"; case .line: "L"; case .cubic: "C"; case .close: "Z"
                }
            }
        }
        #expect(!kinds(.regular).isEmpty)
        #expect(kinds(.ultralight) == kinds(.regular))
        #expect(kinds(.black) == kinds(.regular))
    }

    @Test("The blank carries no vector-editor artifacts")
    func noEditorArtifacts() throws {
        let text = String(decoding: try fixture("blank-template-apple-v7"),
                          as: UTF8.self)
        // The whole point of the change: none of Sketch's fingerprints.
        #expect(!text.contains("fill-rule"))
        #expect(!text.contains("<title>"))
        #expect(!text.contains("custom."))
        #expect(!text.contains("id=\"Group\""))
    }
}
