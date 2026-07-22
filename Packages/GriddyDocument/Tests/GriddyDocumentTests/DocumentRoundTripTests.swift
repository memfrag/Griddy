//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
import GriddyGeometry
import GriddyConstraints
@testable import GriddyDocument

private func makeDocument() -> SymbolDocument {
    var document = SymbolDocument.new(
        name: "g.magnify",
        templateMetrics: .blankTemplate,
        appVersion: "1.0.0",
        author: "Martin Johannesson",
        now: Date(timeIntervalSince1970: 1_770_000_000)
    )

    let outer = CirclePrimitive(center: IconPoint(x: 8, y: 9), radius: 4)
    let handle = LinePrimitive(start: IconPoint(x: 11, y: 6),
                               end: IconPoint(x: 14, y: 3))
    let inner = ArcPrimitive(center: IconPoint(x: 8, y: 9),
                             radius: 2.5,
                             startAngle: IconAngle(degrees: 45),
                             endAngle: IconAngle(degrees: 315))

    document.primitives = [.circle(outer), .line(handle), .arc(inner)]
    document.layers = [
        SymbolLayer(name: "Outer Body", role: .outerBody, primitiveIDs: [outer.id]),
        SymbolLayer(name: "Handle", role: .detail, primitiveIDs: [handle.id]),
        SymbolLayer(name: "Inner Counter", role: .cutout, primitiveIDs: [inner.id])
    ]
    document.constraints = [
        .centered(CenteredConstraint(primitiveID: outer.id, axis: .horizontal)),
        .concentric(ConcentricConstraint(primitiveIDs: [outer.id, inner.id])),
        .tangent(TangentConstraint(primitiveID: handle.id,
                                   targetPrimitiveID: outer.id))
    ]
    document.metadata.designIntent = .circular

    var black = SymbolMaster(weight: .black)
    black.setAdjustment(MasterAdjustment(primitiveID: outer.id,
                                         strokeWidthDelta: 0.4,
                                         radiusDelta: -0.1))
    document.masters = [SymbolMaster(weight: .ultralight),
                        SymbolMaster(weight: .regular),
                        black]

    return document
}

@Suite("Document package round trip")
struct DocumentRoundTripTests {

    @Test("A document survives a write/read cycle unchanged")
    func roundTrip() throws {
        let original = makeDocument()
        let package = SymbolDocumentPackage(document: original)

        let wrapper = try package.fileWrapper()
        let restored = try SymbolDocumentPackage.read(from: wrapper)

        #expect(restored.document == original)
    }

    @Test("The package contains the expected files")
    func packageLayout() throws {
        let package = SymbolDocumentPackage(document: makeDocument())
        let wrapper = try package.fileWrapper()

        let names = Set((wrapper.fileWrappers ?? [:]).keys)
        #expect(names == ["metadata.json", "document.json", "geometry.json",
                          "constraints.json", "masters.json"])
    }

    @Test("Primitives, layers, constraints and masters all survive")
    func contentsSurvive() throws {
        let original = makeDocument()
        let wrapper = try SymbolDocumentPackage(document: original).fileWrapper()
        let restored = try SymbolDocumentPackage.read(from: wrapper).document

        #expect(restored.primitives.count == 3)
        #expect(restored.layers.count == 3)
        #expect(restored.constraints.count == 3)
        #expect(restored.masters.count == 3)
        #expect(restored.metadata.designIntent == .circular)
    }

    @Test("Primitive identity is stable across a round trip")
    func identityIsStable() throws {
        let original = makeDocument()
        let wrapper = try SymbolDocumentPackage(document: original).fileWrapper()
        let restored = try SymbolDocumentPackage.read(from: wrapper).document

        #expect(restored.primitives.map(\.id) == original.primitives.map(\.id))

        // Layer membership must still resolve after the trip, or the document
        // renders empty even though the primitives are present.
        #expect(restored.danglingPrimitiveIDs.isEmpty)
        #expect(restored.orphanedPrimitiveIDs.isEmpty)
    }

    @Test("Master adjustments stay keyed to their primitive")
    func masterAdjustments() throws {
        let original = makeDocument()
        let wrapper = try SymbolDocumentPackage(document: original).fileWrapper()
        let restored = try SymbolDocumentPackage.read(from: wrapper).document

        let outerID = try #require(original.layers.first?.primitiveIDs.first)
        let black = try #require(restored.master(for: .black))
        let adjustment = try #require(black.adjustment(for: outerID))

        #expect(adjustment.strokeWidthDelta == 0.4)
        #expect(adjustment.radiusDelta == -0.1)
    }

    @Test("The source template is preserved byte for byte")
    func sourceTemplatePreserved() throws {
        let svg = Data("<svg><!-- untouched --></svg>".utf8)
        let package = SymbolDocumentPackage(document: makeDocument(),
                                            sourceTemplate: svg)

        let wrapper = try package.fileWrapper()
        #expect(wrapper.fileWrappers?["source-template.svg"] != nil)

        let restored = try SymbolDocumentPackage.read(from: wrapper)
        #expect(restored.sourceTemplate == svg)
    }

    @Test("Dates survive at second precision")
    func datesSurvive() throws {
        let original = makeDocument()
        let wrapper = try SymbolDocumentPackage(document: original).fileWrapper()
        let restored = try SymbolDocumentPackage.read(from: wrapper).document

        #expect(restored.metadata.createdAt == original.metadata.createdAt)
        #expect(restored.metadata.modifiedAt == original.metadata.modifiedAt)
    }
}

@Suite("New document")
struct NewDocumentTests {

    @Test("A new document derives its coordinate system from the template")
    func derivesFromTemplate() {
        let document = SymbolDocument.new(name: "Untitled",
                                          templateMetrics: .blankTemplate,
                                          appVersion: "1.0.0")

        #expect(document.coordinateSystem.templateMetrics == .blankTemplate)
        #expect(document.grid.canvasSize.height == 16)

        // One unit is a sixteenth of cap height, and cap height now comes from
        // a real SF Symbols template rather than a round placeholder.
        let expectedUnit = TemplateMetrics.blankTemplate.capHeight / 16
        #expect(abs(document.coordinateSystem.unitInTemplateSpace - expectedUnit) < 1e-12)
        #expect(abs(TemplateMetrics.blankTemplate.capHeight - 70.459) < 1e-3,
                "measured from Baseline-S and Capline-S of a v7.0 template")
    }

    @Test("A new document starts with the three authored masters")
    func authoredMasters() {
        let document = SymbolDocument.new(name: "Untitled",
                                          templateMetrics: .blankTemplate,
                                          appVersion: "1.0.0")

        #expect(document.masters.count == 3)
        #expect(document.masters.allSatisfy { $0.scale == .medium })
        #expect(Set(document.masters.map(\.weight)) == [.ultralight, .regular, .black])
    }

    @Test("A new document has default key shapes and one layer")
    func defaults() {
        let document = SymbolDocument.new(name: "Untitled",
                                          templateMetrics: .blankTemplate,
                                          appVersion: "1.0.0")

        #expect(document.keyShapes.all.count == 4)
        #expect(document.layers.count == 1)
        #expect(document.primitives.isEmpty)
        #expect(document.metadata.documentFormatVersion == DocumentFormatVersion.current)
    }
}
