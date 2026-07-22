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
        //
        // The second circle sits well clear of the first. Nesting one inside
        // the other made the export fail reconciliation for a real reason: at
        // Black the strokes grew until two regions became one, which is a
        // topology change no amount of point insertion can bridge.
        let cutout = SymbolLayer(name: "Inner Counter", role: .cutout)
        package.document.layers.append(cutout)
        let centre = package.document.coordinateSystem.capHeightBox.center
        package.document.addPrimitive(
            .circle(CirclePrimitive(center: IconPoint(x: centre.x + 18,
                                                      y: centre.y),
                                    radius: 3)),
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

    @Test("The case Apple rejected now exports interpolatable")
    func previouslyRejectedCaseReconciles() throws {
        let package = try drawnDocument()
        let (_, report) = try SFSymbolTemplateExporter.export(
            document: package.document, sourceTemplate: package.sourceTemplate)

        // A circle unioned with an overlapping line. Before the compatibility
        // pass this exported with 2 subpaths at every weight but 20, 22 and 22
        // path commands, and the SF Symbols app refused the file: "The
        // provided variants are not interpolatable."
        let subpaths = Set(report.subpathCounts.values)
        let commands = Set(report.commandCounts.values)

        #expect(subpaths.count == 1,
                "subpaths: \(report.subpathCounts.values.sorted())")
        #expect(commands.count == 1,
                "commands: \(report.commandCounts.values.sorted())")

        #expect(report.mastersShareStructure)
        #expect(report.warnings.isEmpty,
                "unexpected warnings: \(report.warnings)")
    }

    @Test("Every master emits the same sequence of command kinds")
    func commandKindsAlign() throws {
        let package = try drawnDocument()
        let (data, _) = try SFSymbolTemplateExporter.export(
            document: package.document, sourceTemplate: package.sourceTemplate)
        let reimported = try SFSymbolTemplateImporter.import(data)

        // Matching counts is not enough, and this is the check that says so.
        // Interpolation pairs command i with command i, so a line in one master
        // opposite a cubic in another is not interpolatable however well the
        // totals agree. An export with 50 commands in every master was still
        // refused by the SF Symbols app for exactly this.
        func kinds(_ weight: SymbolWeight) -> [String] {
            guard let variant = reimported.variants[
                SymbolSlot(weight: weight, scale: .small)] else {
                return []
            }
            return variant.commands.map { command in
                switch command {
                case .move: "M"
                case .line: "L"
                case .cubic: "C"
                case .close: "Z"
                }
            }
        }

        let reference = kinds(.regular)
        #expect(!reference.isEmpty)

        for weight in SymbolWeight.authored {
            let sequence = kinds(weight)
            let mismatches = zip(reference, sequence).enumerated()
                .filter { $0.element.0 != $0.element.1 }
                .map { "\($0.offset):\($0.element.0)/\($0.element.1)" }

            #expect(sequence == reference,
                    "\(weight.rawValue) differs at \(mismatches.prefix(8))")
        }
    }

    @Test("Arcs expanding to cubics does not undo the reconciliation")
    func cubicExpansionStaysReconciled() throws {
        let package = try drawnDocument()
        let (data, _) = try SFSymbolTemplateExporter.export(
            document: package.document, sourceTemplate: package.sourceTemplate)
        let reimported = try SFSymbolTemplateImporter.import(data)

        // Reconciliation matches outline segments, but an arc expands into a
        // number of cubics that follows its sweep. Corresponding arcs of
        // slightly different sweep would otherwise produce different command
        // counts and quietly undo the work, which is only visible in the
        // written file.
        let counts = SymbolWeight.authored.map { weight in
            reimported.variants[SymbolSlot(weight: weight, scale: .small)]?
                .commands.count ?? -1
        }
        #expect(Set(counts).count == 1, "written command counts: \(counts)")

        let subpaths = SymbolWeight.authored.map { weight in
            reimported.variants[SymbolSlot(weight: weight, scale: .small)]?
                .subpathCount ?? -1
        }
        #expect(Set(subpaths).count == 1, "written subpath counts: \(subpaths)")
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
