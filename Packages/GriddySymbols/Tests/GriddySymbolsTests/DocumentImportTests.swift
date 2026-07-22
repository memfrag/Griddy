//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
import GriddyGeometry
import GriddyDocument
@testable import GriddySymbols

private func fixture(_ name: String) throws -> Data {
    let url = try #require(
        Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "svg"))
    return try Data(contentsOf: url)
}

private func approximately(_ value: Double,
                           _ expected: Double,
                           tolerance: Double = 1e-6) -> Bool {
    abs(value - expected) <= tolerance
}

@Suite("Path writing")
struct SVGPathWriterTests {

    @Test("Commands round trip through write and parse")
    func roundTrip() throws {
        let original: [SVGPathCommand] = [
            .move(to: IconPoint(x: 1, y: 2)),
            .line(to: IconPoint(x: 3.5, y: -4)),
            .cubic(control1: IconPoint(x: 5, y: 6),
                   control2: IconPoint(x: 7, y: 8),
                   to: IconPoint(x: 9, y: 10)),
            .close
        ]

        let restored = try SVGPathData.parse(SVGPathWriter.write(original))
        #expect(restored == original)
    }

    @Test("Whole numbers are written without a decimal point")
    func compactNumbers() {
        let written = SVGPathWriter.write([.move(to: IconPoint(x: 8, y: 16))])
        #expect(written == "M8,16")
    }

    @Test("Mapping transforms every point including control points")
    func mapping() {
        let command = SVGPathCommand.cubic(control1: IconPoint(x: 1, y: 1),
                                           control2: IconPoint(x: 2, y: 2),
                                           to: IconPoint(x: 3, y: 3))
        let shifted = command.mapped { IconPoint(x: $0.x + 10, y: $0.y) }

        guard case .cubic(let c1, let c2, let end) = shifted else {
            Issue.record("Expected a cubic")
            return
        }
        #expect(c1.x == 11)
        #expect(c2.x == 12)
        #expect(end.x == 13)
    }
}

@Suite("Template to document")
struct DocumentImportTests {

    @Test("An imported template produces a usable document")
    func importsToDocument() throws {
        let package = try SFSymbolTemplateImporter.importDocument(
            fixture("authoring-template-v7"), appVersion: "1.0.0")

        #expect(package.document.metadata.name.contains("cup"))
        #expect(package.document.coordinateSystem.canvasBounds.size.height == 16)
        #expect(package.sourceTemplate != nil, "the original must be preserved")
    }

    @Test("The coordinate system comes from the template's guides")
    func coordinateSystem() throws {
        let package = try SFSymbolTemplateImporter.importDocument(
            fixture("authoring-template-v7"), appVersion: "1.0.0")
        let system = package.document.coordinateSystem

        #expect(approximately(system.templateMetrics.capHeight, 70.459, tolerance: 1e-3))
        #expect(approximately(system.unitInTemplateSpace, 70.459 / 16, tolerance: 1e-3))
    }

    @Test("Artwork arrives as imported paths, never as semantic primitives")
    func artworkIsNotConverted() throws {
        let package = try SFSymbolTemplateImporter.importDocument(
            fixture("authoring-template-v7"), appVersion: "1.0.0")

        #expect(!package.document.primitives.isEmpty)
        for primitive in package.document.primitives {
            #expect(!primitive.isSemantic,
                    "import must not infer semantics; that is an explicit action")
            guard case .importedPath = primitive else {
                Issue.record("Expected an imported path, got \(primitive.kindName)")
                return
            }
        }
    }

    @Test("Imported geometry is converted into unit space")
    func convertedToUnitSpace() throws {
        let package = try SFSymbolTemplateImporter.importDocument(
            fixture("authoring-template-v7"), appVersion: "1.0.0")

        guard case .importedPath(let imported) =
                try #require(package.document.primitives.first) else {
            Issue.record("Expected an imported path")
            return
        }

        let commands = try SVGPathData.parse(imported.pathData)
        let points = commands.compactMap { command -> IconPoint? in
            if case .move(let to) = command { return to }
            if case .line(let to) = command { return to }
            if case .cubic(_, _, let to) = command { return to }
            return nil
        }

        // Template coordinates are in the hundreds; unit coordinates sit on a
        // 16-unit canvas. Landing in the right space is the whole point of
        // converting on import rather than at render time.
        #expect(!points.isEmpty)
        for point in points {
            #expect(abs(point.x) < 64, "x = \(point.x) is not in unit space")
            #expect(abs(point.y) < 64, "y = \(point.y) is not in unit space")
        }
    }

    @Test("Imported artwork sits inside a layer so it renders")
    func artworkIsClaimedByALayer() throws {
        let package = try SFSymbolTemplateImporter.importDocument(
            fixture("authoring-template-v7"), appVersion: "1.0.0")

        #expect(package.document.orphanedPrimitiveIDs.isEmpty)
        #expect(package.document.danglingPrimitiveIDs.isEmpty)
        #expect(!package.document.primitivesInDrawOrder.isEmpty)
    }

    @Test("Imported artwork lands on the canvas, not off it")
    func artworkLandsOnCanvas() throws {
        // Metrics and artwork must come from the same scale. Deriving the
        // coordinate system from the Medium guides and importing the Small
        // artwork puts the geometry hundreds of units away, which renders as a
        // blank canvas -- correct primitive count, nothing visible.
        for name in ["authoring-template-v7", "static-template-v7"] {
            let package = try SFSymbolTemplateImporter.importDocument(
                fixture(name), appVersion: "1.0.0")

            guard case .importedPath(let imported) =
                    try #require(package.document.primitives.first) else {
                Issue.record("\(name): expected an imported path")
                return
            }

            let commands = try SVGPathData.parse(imported.pathData)
            let points = commands.compactMap { command -> IconPoint? in
                if case .move(let to) = command { return to }
                if case .line(let to) = command { return to }
                if case .cubic(_, _, let to) = command { return to }
                return nil
            }

            let bounds = try #require(PrimitiveGeometry.bounds(containing: points))
            let canvas = package.document.coordinateSystem.canvasBounds

            #expect(bounds.intersects(canvas.inset(by: -4)),
                    "\(name): artwork at \(bounds) is nowhere near the canvas \(canvas)")
        }
    }

    @Test("A static export is not named after its Notes group")
    func staticExportName() throws {
        let package = try SFSymbolTemplateImporter.importDocument(
            fixture("static-template-v7"), appVersion: "1.0.0")

        // A static export has no symbol-named wrapper group, so a naive
        // "first group" fallback picks up "Notes" and names the document after
        // template furniture.
        #expect(package.document.metadata.name != "Notes")
        #expect(!["Guides", "Symbols", "Group", "Margins"]
            .contains(package.document.metadata.name))
    }

    @Test("A static export imports too, taking its Regular master")
    func staticExport() throws {
        let package = try SFSymbolTemplateImporter.importDocument(
            fixture("static-template-v7"), appVersion: "1.0.0")

        #expect(package.document.primitives.count == 1,
                "one master becomes geometry, not all 27")

        guard case .importedPath(let imported) =
                try #require(package.document.primitives.first) else {
            Issue.record("Expected an imported path")
            return
        }
        #expect(imported.sourceElementID?.hasPrefix("Regular") == true)
    }
}

@Suite("Blank template")
struct BlankTemplateTests {

    @Test("A template with empty slots imports as an empty document")
    func emptySlots() throws {
        // A blank template has its slot groups in place with no artwork. That
        // is what New Symbol starts from, so it must not be treated as a
        // malformed file.
        let svg = """
        <svg><g id="Symbols">
        <g id="Ultralight-S"></g><g id="Regular-S"></g><g id="Black-S"></g>
        </g>
        <g id="Guides">
        <line id="Baseline-S" x1="20" y1="95.215" x2="200" y2="95.215"/>
        <line id="Capline-S" x1="20" y1="24.756" x2="200" y2="24.756"/>
        </g></svg>
        """

        let package = try SFSymbolTemplateImporter.importDocument(
            Data(svg.utf8), appVersion: "1.0.0")

        #expect(package.document.primitives.isEmpty, "a blank template has no artwork")
        #expect(package.document.layers.count == 1)
        #expect(approximately(package.document.coordinateSystem.templateMetrics.capHeight,
                              70.459, tolerance: 1e-3),
                "but it still carries real metrics")
    }

    @Test("A file with no slot groups at all is still refused")
    func noSlotsIsStillAnError() {
        let svg = """
        <svg><g id="Symbols"></g>
        <g id="Guides">
        <line id="Baseline-S" x1="0" y1="100" x2="10" y2="100"/>
        <line id="Capline-S" x1="0" y1="30" x2="10" y2="30"/>
        </g></svg>
        """

        #expect(throws: TemplateImportError.noVariants) {
            try SFSymbolTemplateImporter.import(Data(svg.utf8))
        }
    }
}
