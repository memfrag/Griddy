//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
import GriddyGeometry
@testable import GriddySymbols

/// Real templates exported by the SF Symbols app, not reconstructions.
private enum Fixture {

    static func data(_ name: String) throws -> Data {
        let url = try #require(
            Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "svg"),
            "Fixture \(name).svg is missing")
        return try Data(contentsOf: url)
    }

    /// The three-master template the SF Symbols app exports for editing.
    static var authoring: Data { get throws { try data("authoring-template-v7") } }

    /// A static export of a system symbol, with all 27 slots populated.
    static var populated: Data { get throws { try data("static-template-v7") } }
}

private func approximately(_ value: Double,
                           _ expected: Double,
                           tolerance: Double = 1e-3) -> Bool {
    abs(value - expected) <= tolerance
}

@Suite("SVG parsing")
struct SVGParsingTests {

    @Test("A template parses into an element tree")
    func parsesTree() throws {
        let root = try SVGParser.parse(Fixture.authoring)

        #expect(root.name == "svg")
        #expect(root.attributes["viewBox"] == "0 0 3300 2200")
        #expect(root.firstDescendant(withID: "Symbols") != nil)
        #expect(root.firstDescendant(withID: "Guides") != nil)
        #expect(root.firstDescendant(withID: "Notes") != nil)
    }

    @Test("Text is gathered from nested tspan elements")
    func nestedText() throws {
        let root = try SVGParser.parse(Fixture.authoring)
        let version = try #require(root.firstDescendant(withID: "template-version"))

        // The label lives in a child tspan, so reading the element's own
        // character data alone would find nothing.
        #expect(version.allText.contains("7.0"))
    }

    @Test("Malformed XML is rejected")
    func malformedXML() {
        #expect(throws: (any Error).self) {
            try SVGParser.parse(Data("<svg><g></svg>".utf8))
        }
    }
}

@Suite("SVG path data")
struct SVGPathDataTests {

    @Test("Absolute commands parse to the right points")
    func absoluteCommands() throws {
        let commands = try SVGPathData.parse("M10,20 L30,40 Z")

        #expect(commands.count == 3)
        #expect(commands[0] == .move(to: IconPoint(x: 10, y: 20)))
        #expect(commands[1] == .line(to: IconPoint(x: 30, y: 40)))
        #expect(commands[2] == .close)
    }

    @Test("Relative commands accumulate from the current point")
    func relativeCommands() throws {
        let commands = try SVGPathData.parse("m10,10 l5,5 l5,5")

        #expect(commands[0] == .move(to: IconPoint(x: 10, y: 10)))
        #expect(commands[1] == .line(to: IconPoint(x: 15, y: 15)))
        #expect(commands[2] == .line(to: IconPoint(x: 20, y: 20)))
    }

    @Test("Repeated operands continue the previous command")
    func implicitRepetition() throws {
        // "L10,10 20,20" means two linetos, not a parse error.
        let commands = try SVGPathData.parse("M0,0 L10,10 20,20")

        #expect(commands.count == 3)
        #expect(commands[2] == .line(to: IconPoint(x: 20, y: 20)))
    }

    @Test("Coordinate pairs after a moveto are implicit linetos")
    func implicitLineAfterMove() throws {
        let commands = try SVGPathData.parse("M0,0 10,10")

        #expect(commands[0] == .move(to: IconPoint(x: 0, y: 0)))
        #expect(commands[1] == .line(to: IconPoint(x: 10, y: 10)),
                "a second pair after M is a lineto, per the SVG grammar")
    }

    @Test("Horizontal and vertical shorthands keep the other coordinate")
    func axisShorthands() throws {
        let commands = try SVGPathData.parse("M5,5 H15 V25")

        #expect(commands[1] == .line(to: IconPoint(x: 15, y: 5)))
        #expect(commands[2] == .line(to: IconPoint(x: 15, y: 25)))
    }

    @Test("Cubic curves keep their control points")
    func cubic() throws {
        let commands = try SVGPathData.parse("M0,0 C1,2 3,4 5,6")

        #expect(commands[1] == .cubic(control1: IconPoint(x: 1, y: 2),
                                      control2: IconPoint(x: 3, y: 4),
                                      to: IconPoint(x: 5, y: 6)))
    }

    @Test("A smooth cubic mirrors the previous control point")
    func smoothCubic() throws {
        let commands = try SVGPathData.parse("M0,0 C1,1 2,2 3,3 S6,6 9,9")

        guard case .cubic(let control1, _, _) = commands[2] else {
            Issue.record("Expected a cubic")
            return
        }
        // Previous control was (2,2) and the current point (3,3), so the
        // reflection is (4,4).
        #expect(control1 == IconPoint(x: 4, y: 4))
    }

    @Test("A quadratic is raised to an equivalent cubic")
    func quadratic() throws {
        let commands = try SVGPathData.parse("M0,0 Q3,3 6,0")

        guard case .cubic(let c1, let c2, let end) = commands[1] else {
            Issue.record("Expected a cubic")
            return
        }
        #expect(approximately(c1.x, 2, tolerance: 1e-9))
        #expect(approximately(c2.x, 4, tolerance: 1e-9))
        #expect(end == IconPoint(x: 6, y: 0))
    }

    @Test("Exponent and sign-separated numbers parse")
    func awkwardNumbers() throws {
        // Apple's templates contain values like 1.13686838e-13, and negative
        // numbers with no separating comma.
        let commands = try SVGPathData.parse("M1.5e2,-3.25L-4-5")

        #expect(commands[0] == .move(to: IconPoint(x: 150, y: -3.25)))
        #expect(commands[1] == .line(to: IconPoint(x: -4, y: -5)))
    }

    @Test("Elliptical arcs are refused rather than approximated")
    func arcsRefused() {
        // Approximating would silently change a designer's geometry, which is
        // exactly what importing must not do.
        #expect(throws: SVGPathParseError.unsupportedCommand("A")) {
            try SVGPathData.parse("M0,0 A5,5 0 0 1 10,10")
        }
    }
}

@Suite("Template import: authoring template")
struct AuthoringTemplateTests {

    @Test("A real three-master template imports")
    func imports() throws {
        let template = try SFSymbolTemplateImporter.import(Fixture.authoring)

        #expect(template.version == "7.0")
        #expect(template.kind == .authoring)
        #expect(template.name.contains("cup"))
    }

    @Test("It contains exactly the three authored masters")
    func threeMasters() throws {
        let template = try SFSymbolTemplateImporter.import(Fixture.authoring)

        #expect(template.variants.count == 3)
        #expect(Set(template.variants.keys.map(\.weight))
                == [.ultralight, .regular, .black])
        #expect(Set(template.variants.keys.map(\.scale)) == [.small],
                "the authoring template holds its masters at one scale")
    }

    @Test("Metrics come from the guides, not from assumptions")
    func metrics() throws {
        let template = try SFSymbolTemplateImporter.import(Fixture.authoring)

        // Measured from the file: Baseline-S 95.215, Capline-S 24.756.
        #expect(approximately(template.metrics.baselineY, 95.215))
        #expect(approximately(template.metrics.caplineY, 24.756))
        #expect(approximately(template.metrics.capHeight, 70.459))
    }

    @Test("A usable coordinate system falls out of the metrics")
    func coordinateSystem() throws {
        let template = try SFSymbolTemplateImporter.import(Fixture.authoring)
        let system = CoordinateSystem(templateMetrics: template.metrics)

        // One unit is a sixteenth of cap height, by definition.
        #expect(approximately(system.unitInTemplateSpace, 70.459 / 16))
        #expect(system.canvasBounds.size.height == 16)

        // The origin maps to the baseline, and 16u up to the capline.
        let origin = system.templatePoint(from: .zero)
        #expect(approximately(origin.y, 95.215))
        let capline = system.templatePoint(from: IconPoint(x: 0, y: 16))
        #expect(approximately(capline.y, 24.756))
    }

    @Test("Artwork is parsed but left as imported path data")
    func artworkPreserved() throws {
        let template = try SFSymbolTemplateImporter.import(Fixture.authoring)
        let regular = try #require(
            template.variants[SymbolSlot(weight: .regular, scale: .small)])

        #expect(regular.elementID == "Regular-S")
        #expect(!regular.pathData.isEmpty)
        #expect(!regular.commands.isEmpty)
        #expect(regular.subpathCount == 6)
    }

    @Test("The source document is preserved byte for byte")
    func sourcePreserved() throws {
        let data = try Fixture.authoring
        let template = try SFSymbolTemplateImporter.import(data)

        #expect(template.source == data)
    }
}

@Suite("Template import: static export")
struct StaticTemplateTests {

    @Test("A fully populated template imports")
    func imports() throws {
        let template = try SFSymbolTemplateImporter.import(Fixture.populated)
        #expect(template.kind == .populated)
    }

    @Test("It contains all 27 weight and scale slots")
    func allSlots() throws {
        let template = try SFSymbolTemplateImporter.import(Fixture.populated)

        #expect(template.variants.count == 27)
        #expect(Set(template.variants.keys) == Set(SymbolSlot.all))
    }

    @Test("Metrics are derived from the Medium guides when present")
    func metrics() throws {
        let template = try SFSymbolTemplateImporter.import(Fixture.populated)

        // Measured from the file: Baseline-M 1126, Capline-M 1055.54.
        #expect(approximately(template.metrics.baselineY, 1126))
        #expect(approximately(template.metrics.capHeight, 70.459, tolerance: 1e-2))
    }

    @Test("Every slot shares the same path topology")
    func topologyIsUniform() throws {
        let template = try SFSymbolTemplateImporter.import(Fixture.populated)

        let subpaths = Set(template.variants.values.map(\.subpathCount))
        let commands = Set(template.variants.values.map(\.commandCount))

        // This is the finding that matters for export: Apple keeps subpath and
        // command counts identical across all 27 slots. Interpolation between
        // masters requires it, and it means exported geometry cannot vary its
        // structure from slot to slot.
        #expect(subpaths.count == 1,
                "expected one subpath count across slots, saw \(subpaths.sorted())")
        #expect(commands.count == 1,
                "expected one command count across slots, saw \(commands.sorted())")
    }
}

@Suite("Template rejection")
struct TemplateRejectionTests {

    @Test("A file without a Symbols group is refused")
    func missingSymbols() {
        let svg = #"<svg><g id="Guides"></g></svg>"#

        #expect(throws: TemplateImportError.missingGroup("Symbols")) {
            try SFSymbolTemplateImporter.import(Data(svg.utf8))
        }
    }

    @Test("A file without a Guides group is refused")
    func missingGuides() {
        let svg = #"<svg><g id="Symbols"></g></svg>"#

        #expect(throws: TemplateImportError.missingGroup("Guides")) {
            try SFSymbolTemplateImporter.import(Data(svg.utf8))
        }
    }

    @Test("An older template version is refused with a clear message")
    func wrongVersion() throws {
        // Rewrite the real fixture's version label rather than inventing a
        // file, so only the version differs from something known to import.
        let original = try String(data: Fixture.authoring, encoding: .utf8) ?? ""
        let downgraded = original.replacingOccurrences(of: "Template v.7.0",
                                                       with: "Template v.4.0")

        do {
            _ = try SFSymbolTemplateImporter.import(Data(downgraded.utf8))
            Issue.record("Expected the import to be refused")
        } catch let error as TemplateImportError {
            #expect(error == .unsupportedVersion(found: "4.0", supported: "7.0"))
            #expect(error.errorDescription?.isEmpty == false)
            #expect(error.recoverySuggestion?.contains("Re-export") == true)
        }
    }

    @Test("A template with no artwork slots is refused")
    func noVariants() {
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

    @Test("Coincident baseline and capline are refused")
    func degenerateMetrics() {
        let svg = """
        <svg><g id="Symbols"><g id="Regular-S"><path d="M0,0 L1,1"/></g></g>
        <g id="Guides">
        <line id="Baseline-S" x1="0" y1="100" x2="10" y2="100"/>
        <line id="Capline-S" x1="0" y1="100" x2="10" y2="100"/>
        </g></svg>
        """

        // A zero cap height would make the unit zero and every coordinate
        // infinite.
        #expect(throws: TemplateImportError.degenerateMetrics) {
            try SFSymbolTemplateImporter.import(Data(svg.utf8))
        }
    }

    @Test("Every path in a variant group is read, not just the first")
    func multiplePathsPerVariant() throws {
        // Apple's templates put the artwork in one path with several subpaths,
        // but a group holding several paths renders as their union. Reading
        // only the first would silently drop geometry.
        let svg = """
        <svg><g id="Symbols"><g id="Regular-S">
        <path d="M0,0 L1,0 L1,1 Z"/>
        <path d="M5,5 L6,5 L6,6 Z"/>
        </g></g>
        <g id="Guides">
        <line id="Baseline-S" x1="0" y1="100" x2="10" y2="100"/>
        <line id="Capline-S" x1="0" y1="30" x2="10" y2="30"/>
        </g></svg>
        """

        let template = try SFSymbolTemplateImporter.import(Data(svg.utf8))
        let variant = try #require(
            template.variants[SymbolSlot(weight: .regular, scale: .small)])

        #expect(variant.subpathCount == 2, "both paths contribute")
    }

    @Test("Unrecognised slot identifiers are skipped, not fatal")
    func unknownSlotIdentifiers() throws {
        let template = try SFSymbolTemplateImporter.import(Fixture.authoring)

        // The file contains many groups that are not artwork slots; they must
        // not be mistaken for variants.
        #expect(template.variants.count == 3)
    }
}
