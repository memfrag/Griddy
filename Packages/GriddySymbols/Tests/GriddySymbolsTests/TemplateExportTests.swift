//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
import GriddyGeometry
import GriddyDocument
@testable import GriddySymbols

private func fixtureData(_ name: String) throws -> Data {
    let url = try #require(
        Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "svg"))
    return try Data(contentsOf: url)
}

/// A document on a real template, with a circle and a line drawn on it.
private func drawnDocument() throws -> SymbolDocumentPackage {
    var package = try SFSymbolTemplateImporter.importDocument(
        fixtureData("authoring-template-v7"), appVersion: "1.0.0")

    // Drop the imported artwork so the export is Griddy's own geometry.
    package.document.primitives = []
    package.document.layers = [SymbolLayer(name: "Outer Body", role: .outerBody)]

    let centre = package.document.coordinateSystem.capHeightBox.center
    package.document.addPrimitive(.circle(
        CirclePrimitive(center: centre, radius: 5)))
    package.document.addPrimitive(.line(LinePrimitive(
        start: IconPoint(x: centre.x + 3, y: centre.y - 3),
        end: IconPoint(x: centre.x + 8, y: centre.y - 8))))

    return package
}

@Suite("Template export")
struct TemplateExportTests {

    @Test("Export writes the three authored masters")
    func writesThreeMasters() throws {
        let package = try drawnDocument()
        let (_, report) = try SFSymbolTemplateExporter.export(
            document: package.document, sourceTemplate: package.sourceTemplate)

        #expect(report.slotsWritten.count == 3)
        #expect(Set(report.slotsWritten.map(\.weight))
                == [.ultralight, .regular, .black])
    }

    @Test("The exported file is still a valid, importable template")
    func roundTrip() throws {
        let package = try drawnDocument()
        let (data, _) = try SFSymbolTemplateExporter.export(
            document: package.document, sourceTemplate: package.sourceTemplate)

        // The strongest available check short of the SF Symbols app: what came
        // out must go back in.
        let reimported = try SFSymbolTemplateImporter.import(data)

        #expect(reimported.version == "7.0")
        #expect(reimported.variants.count == 3)
        #expect(reimported.metrics.capHeight == package.document
            .coordinateSystem.templateMetrics.capHeight)
    }

    @Test("Everything except the artwork survives byte for byte")
    func preservesTemplate() throws {
        let package = try drawnDocument()
        let original = try #require(package.sourceTemplate)
        let (data, _) = try SFSymbolTemplateExporter.export(
            document: package.document, sourceTemplate: original)

        let before = try #require(String(data: original, encoding: .utf8))
        let after = try #require(String(data: data, encoding: .utf8))

        // Substituting into the original text rather than re-serialising a
        // parsed tree is what makes this true. Notes, guides, margins and every
        // attribute Griddy never looked at come through unchanged.
        for marker in ["Template v.7.0", "id=\"Notes\"", "id=\"Guides\"",
                       "Baseline-S", "Capline-S", "left-margin-Regular-S",
                       "Weight/Scale Variations"] {
            #expect(after.contains(marker), "lost \(marker)")
        }

        // The only structural difference is the artwork itself.
        #expect(before.count != after.count, "the artwork should have changed")
    }

    @Test("Geometry survives the round trip in the right place")
    func geometryRoundTrips() throws {
        let package = try drawnDocument()
        let (data, _) = try SFSymbolTemplateExporter.export(
            document: package.document, sourceTemplate: package.sourceTemplate)

        let reimported = try SFSymbolTemplateImporter.import(data)
        let variant = try #require(reimported.variants[
            SymbolSlot(weight: .regular, scale: .small)])

        let system = package.document.coordinateSystem
        let points = variant.commands.compactMap { command -> IconPoint? in
            if case .move(let to) = command { return system.iconPoint(from: to) }
            if case .line(let to) = command { return system.iconPoint(from: to) }
            if case .cubic(_, _, let to) = command { return system.iconPoint(from: to) }
            return nil
        }
        let bounds = try #require(PrimitiveGeometry.bounds(containing: points))

        // The drawn circle is radius 5 about the cap-height centre, so the
        // artwork must come back somewhere near there rather than at the
        // origin or off in template coordinates.
        let expected = system.capHeightBox.center
        #expect(abs(bounds.center.x - expected.x) < 3,
                "x centre \(bounds.center.x) is nowhere near \(expected.x)")
        #expect(abs(bounds.center.y - expected.y) < 3,
                "y centre \(bounds.center.y) is nowhere near \(expected.y)")
    }

    @Test("Heavier masters export more area than lighter ones")
    func mastersDiffer() throws {
        let package = try drawnDocument()
        let (data, _) = try SFSymbolTemplateExporter.export(
            document: package.document, sourceTemplate: package.sourceTemplate)
        let reimported = try SFSymbolTemplateImporter.import(data)

        func commandCount(_ weight: SymbolWeight) -> Int {
            reimported.variants[SymbolSlot(weight: weight, scale: .small)]?
                .commands.count ?? 0
        }

        // All three slots must carry real, distinct artwork. Identical data
        // across masters would mean weight propagation never reached export.
        #expect(commandCount(.ultralight) > 0)
        #expect(commandCount(.regular) > 0)
        #expect(commandCount(.black) > 0)

        let ultralight = reimported.variants[
            SymbolSlot(weight: .ultralight, scale: .small)]?.pathData
        let black = reimported.variants[
            SymbolSlot(weight: .black, scale: .small)]?.pathData
        #expect(ultralight != black, "the masters should not be identical")
    }

    @Test("Arcs are written as cubics, never as elliptical arc commands")
    func noArcCommands() throws {
        let package = try drawnDocument()
        let (data, _) = try SFSymbolTemplateExporter.export(
            document: package.document, sourceTemplate: package.sourceTemplate)
        let reimported = try SFSymbolTemplateImporter.import(data)

        let variant = try #require(reimported.variants[
            SymbolSlot(weight: .regular, scale: .small)])

        // Apple's templates use only M, L, C and Z. Griddy's own importer
        // refuses A outright, so emitting one would make its own output
        // unreadable.
        #expect(!variant.pathData.contains("A"))
        #expect(!variant.pathData.contains("a"))
        #expect(variant.pathData.contains("C"), "a circle must produce curves")
    }
}

@Suite("Export refusals")
struct ExportRefusalTests {

    @Test("A document with no source template cannot be exported")
    func noSourceTemplate() {
        let document = SymbolDocument.new(name: "Test",
                                          templateMetrics: .blankTemplate,
                                          appVersion: "1.0.0")

        #expect(throws: TemplateExportError.noSourceTemplate) {
            try SFSymbolTemplateExporter.export(document: document,
                                                sourceTemplate: nil)
        }
    }

    @Test("A fully populated template is refused as an export target")
    func staticExportRefused() throws {
        let package = try SFSymbolTemplateImporter.importDocument(
            fixtureData("static-template-v7"), appVersion: "1.0.0")

        // Writing three masters into 27 slots would leave 24 showing the
        // symbol it was exported from, which is worse than refusing.
        do {
            _ = try SFSymbolTemplateExporter.export(
                document: package.document, sourceTemplate: package.sourceTemplate)
            Issue.record("Expected the export to be refused")
        } catch let error as TemplateExportError {
            #expect(error == .notAnAuthoringTemplate(slotCount: 27))
            #expect(error.recoverySuggestion?.contains("blank template") == true)
        }
    }
}

@Suite("Export report")
struct ExportReportTests {

    @Test("The report lists which subpaths belong to which layer")
    func layerAssignments() throws {
        var package = try drawnDocument()

        // Two layers, so the checklist has something to distinguish.
        let cutout = SymbolLayer(name: "Inner Counter", role: .cutout)
        package.document.layers.append(cutout)
        let centre = package.document.coordinateSystem.capHeightBox.center
        package.document.addPrimitive(
            .circle(CirclePrimitive(center: centre, radius: 2)),
            toLayerWithID: cutout.id)

        let (_, report) = try SFSymbolTemplateExporter.export(
            document: package.document, sourceTemplate: package.sourceTemplate)

        #expect(report.layerAssignments.count == 2)

        let names = report.layerAssignments.map(\.layerName)
        #expect(names == ["Outer Body", "Inner Counter"],
                "assignments follow layer order, which is subpath order")

        // Ranges must be contiguous and start at one, or the checklist points
        // the designer at the wrong geometry.
        #expect(report.layerAssignments[0].firstSubpath == 1)
        let first = report.layerAssignments[0]
        #expect(report.layerAssignments[1].firstSubpath
                == first.firstSubpath + first.subpathCount)
    }

    @Test("Masters that do not share structure are reported, not shipped quietly")
    func structureMismatchIsReported() throws {
        let package = try drawnDocument()
        let (_, report) = try SFSymbolTemplateExporter.export(
            document: package.document, sourceTemplate: package.sourceTemplate)

        // A circle unioned with an overlapping line produces the same two
        // regions at every weight, but a different number of path commands,
        // because boolean resolution cuts the outlines at different places as
        // the stroke grows. This is precisely the case the outline
        // compatibility pass exists to fix, and it is not hypothetical: it
        // arises from two primitives.
        #expect(Set(report.subpathCounts.values).count == 1,
                "subpaths agree: \(report.subpathCounts.values.sorted())")
        #expect(Set(report.commandCounts.values).count > 1,
                "commands should differ: \(report.commandCounts.values.sorted())")

        #expect(!report.mastersShareStructure,
                "comparing subpaths alone would wrongly call this compatible")
        #expect(report.warnings.contains { $0.contains("command counts") },
                "the mismatch must be reported")
    }

    @Test("Matching masters report no structural warning")
    func structureMatchIsQuiet() throws {
        var package = try drawnDocument()

        // One circle alone outlines to a ring at every weight: two contours,
        // same commands, no booleans to shift anything.
        package.document.primitives = []
        package.document.layers = [SymbolLayer(name: "Outer Body", role: .outerBody)]
        package.document.addPrimitive(.circle(CirclePrimitive(
            center: package.document.coordinateSystem.capHeightBox.center,
            radius: 5)))

        let (_, report) = try SFSymbolTemplateExporter.export(
            document: package.document, sourceTemplate: package.sourceTemplate)

        let detail = "subpaths \(report.subpathCounts.values.sorted()), "
            + "commands \(report.commandCounts.values.sorted())"
        #expect(report.mastersShareStructure, "\(detail)")
        #expect(report.warnings.isEmpty)
    }

    @Test("A subpath range reads as a human would write it")
    func rangeFormatting() {
        let single = ExportReport.LayerAssignment(
            layerName: "A", role: .detail, firstSubpath: 4, subpathCount: 1)
        let span = ExportReport.LayerAssignment(
            layerName: "B", role: .outerBody, firstSubpath: 1, subpathCount: 3)

        #expect(single.range == "subpath 4")
        #expect(span.range == "subpath 1-3")
    }
}
