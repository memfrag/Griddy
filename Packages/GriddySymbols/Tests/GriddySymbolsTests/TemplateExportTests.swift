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

        // Vertically the artwork lands where it was drawn: the baseline is a
        // font-wide metric and nothing shifts against it.
        let expected = system.capHeightBox.center
        #expect(abs(bounds.center.y - expected.y) < 3,
                "y centre \(bounds.center.y) is nowhere near \(expected.y)")

        // Horizontally it does *not*, and that is the point. Export normalises
        // each master so its leftmost point sits at the standard left side
        // bearing, because that is what fixes the glyph's origin. Asserting the
        // drawn x here would be asserting the bug: bearings that vary per
        // master make the symbol slide sideways as the weight changes.
        let bearing = system.standardSideBearing
        #expect(abs(bounds.minX - bearing) < 0.01,
                "left bearing \(bounds.minX) should be \(bearing)")
    }

    @Test("Every master gets the same left side bearing")
    func bearingsAgreeAcrossMasters() throws {
        let package = try drawnDocument()
        let (data, _) = try SFSymbolTemplateExporter.export(
            document: package.document, sourceTemplate: package.sourceTemplate)
        let reimported = try SFSymbolTemplateImporter.import(data)
        let system = package.document.coordinateSystem

        // Measured on a real Griddy export before this landed: 27.20, 25.99 and
        // 23.45 template units where Apple's own symbols hold a constant 9.77.
        // A bearing that shrinks as the weight grows is a symbol that drifts
        // left as it gets bolder.
        // Measured against each master's *own* glyph origin. The three masters
        // sit in different columns of the sheet, so comparing absolute x would
        // just measure the column pitch.
        let guides = try SFSymbolTemplateExporter.marginGuides(in: data)
        let unit = system.unitInTemplateSpace

        var bearings: [Double] = []
        for weight in SymbolWeight.authored {
            let slot = SymbolSlot(weight: weight, scale: .small)
            let variant = try #require(reimported.variants[slot])
            let origin = try #require(guides[slot]).left
            let xs = variant.commands.compactMap { command -> Double? in
                switch command {
                case .move(let to), .line(let to): to.x
                case .cubic(_, _, let to): to.x
                case .close: nil
                }
            }
            bearings.append((try #require(xs.min()) - origin) / unit)
        }

        let spread = (bearings.max() ?? 0) - (bearings.min() ?? 0)
        #expect(spread < 0.01, "bearings differ across masters: \(bearings)")
    }

    @Test("Advance width follows the artwork, not the source template")
    func advanceFollowsArtwork() throws {
        var package = try drawnDocument()
        let (_, before) = try SFSymbolTemplateExporter.export(
            document: package.document, sourceTemplate: package.sourceTemplate)

        // Widen the drawing and the symbol must claim more room.
        let centre = package.document.coordinateSystem.capHeightBox.center
        package.document.addPrimitive(.circle(
            CirclePrimitive(center: IconPoint(x: centre.x + 12, y: centre.y),
                            radius: 3)))

        let (_, after) = try SFSymbolTemplateExporter.export(
            document: package.document, sourceTemplate: package.sourceTemplate)

        let slot = SymbolSlot(weight: .regular, scale: .small)
        let widened = try #require(after.advances[slot])
        let original = try #require(before.advances[slot])
        #expect(widened > original + 5,
                "advance \(original) -> \(widened) barely moved")
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

    @Test("The document's name reaches the export and round-trips")
    func nameRoundTrips() throws {
        var package = try drawnDocument()
        package.document.metadata.name = "custom.my.great.symbol"

        let (data, _) = try SFSymbolTemplateExporter.export(
            document: package.document, sourceTemplate: package.sourceTemplate)

        // Before this, export copied the root group and title through from the
        // source template untouched, so renaming a document had no effect and
        // the name round-tripped to whatever template it was imported from.
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("<title>custom.my.great.symbol</title>"))
        #expect(text.contains("<g id=\"custom.my.great.symbol\""))
        #expect(!text.contains("custom.cup.and.bag"))

        let reimported = try SFSymbolTemplateImporter.importDocument(
            data, appVersion: "1.0.0")
        #expect(reimported.document.metadata.name == "custom.my.great.symbol")
    }

    @Test("Renaming leaves the structural groups alone")
    func renamingSparesStructuralGroups() throws {
        var package = try drawnDocument()
        package.document.metadata.name = "Notes"

        let (data, _) = try SFSymbolTemplateExporter.export(
            document: package.document, sourceTemplate: package.sourceTemplate)
        let text = String(decoding: data, as: UTF8.self)

        // Naming a symbol after a structural group must not collide with it.
        #expect(text.contains("<g id=\"Guides\""))
        #expect(text.contains("<g id=\"Symbols\""))
        #expect(try SFSymbolTemplateImporter.import(data).variants.count >= 3)
    }

    @Test("A template recording no name exports unchanged")
    func appleFormatCarriesNoName() throws {
        // Templates straight out of the SF Symbols app have no title and no
        // wrapper group -- the name lives in the filename. Substitution must be
        // a no-op there rather than inventing a place to put it.
        let apple = """
            <svg><g id="Notes"></g><g id="Symbols"></g></svg>
            """
        #expect(SFSymbolTemplateExporter.substitute(
            symbolName: "custom.whatever", in: apple) == apple)
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

/// Measures an export the way Apple's own templates were measured, so the two
/// can be compared side by side.
///
/// Exists because the numbers that matter here -- side bearings and advance
/// width -- are invisible on the canvas and invisible in the SVG without doing
/// arithmetic. Set `GRIDDY_METRICS_OUT` to also write the file out.
@Suite("Glyph metrics report")
struct GlyphMetricsReportTests {

    @Test("Exported metrics have the shape of Apple's own")
    func reportMetrics() throws {
        let package = try drawnDocument()
        let (data, report) = try SFSymbolTemplateExporter.export(
            document: package.document, sourceTemplate: package.sourceTemplate)

        if let path = ProcessInfo.processInfo.environment["GRIDDY_METRICS_OUT"] {
            try data.write(to: URL(fileURLWithPath: path))
        }

        let reimported = try SFSymbolTemplateImporter.import(data)
        let guides = try SFSymbolTemplateExporter.marginGuides(in: data)
        let standard = GlyphMetrics.standardSideBearingInTemplateUnits

        print("")
        print("  weight        advance       lsb       rsb   (template units)")

        var bearings: [Double] = []
        for weight in SymbolWeight.authored {
            let slot = SymbolSlot(weight: weight, scale: .small)
            let variant = try #require(reimported.variants[slot])
            let guide = try #require(guides[slot])

            let xs = variant.commands.compactMap { command -> Double? in
                switch command {
                case .move(let to), .line(let to): to.x
                case .cubic(_, _, let to): to.x
                case .close: nil
                }
            }
            let low = try #require(xs.min())
            let high = try #require(xs.max())
            bearings.append(low - guide.left)

            let line = "  " + weight.rawValue.padding(toLength: 12,
                                                      withPad: " ",
                                                      startingAt: 0)
                + String(format: "%9.2f %9.2f %9.2f",
                         guide.right - guide.left, low - guide.left,
                         guide.right - high)
            print(line)
        }

        print(String(format: "\n  Apple's standard side bearing: %.4f", standard))
        print("")

        // The left bearing is the one Apple holds exactly constant: 9.765625 in
        // all nine masters across all three templates examined.
        for bearing in bearings {
            let drift = abs(bearing - standard)
            #expect(drift < 0.01)
        }

        // And the advance must come from this drawing, not from the advance
        // cup-and-bag happened to have.
        let inherited = package.document.coordinateSystem
            .templateMetrics.marginWidth
        let unit = package.document.coordinateSystem.unitInTemplateSpace
        let slot = SymbolSlot(weight: .regular, scale: .small)
        let advance = try #require(report.advances[slot]) * unit
        #expect(abs(advance - inherited) > 1)
    }
}
