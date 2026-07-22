//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry
import GriddyDocument

extension SymbolDocument {

    /// Builds a document from a parsed template.
    ///
    /// This is the single construction path for both New Symbol and Import
    /// Template: a new document is a blank template run through the same
    /// importer, so no document ever lacks a template-derived coordinate
    /// system. See spec 7.1 and 9.1.
    public init(template: SFSymbolTemplate,
                appVersion: String,
                author: String? = nil,
                now: Date = Date()) {
        let coordinateSystem = CoordinateSystem(templateMetrics: template.metrics)

        self.init(
            metadata: SymbolMetadata(name: template.name,
                                     author: author,
                                     createdAt: now,
                                     modifiedAt: now,
                                     appVersion: appVersion),
            coordinateSystem: coordinateSystem,
            grid: .default(for: coordinateSystem),
            keyShapes: .default(for: coordinateSystem),
            layers: [SymbolLayer(name: "Imported", role: .outerBody)]
        )

        // Artwork arrives as fallback paths and is never converted on the way
        // in. Inference is an explicit, per-path action the designer takes
        // afterwards. See spec 14.3.
        for primitive in Self.importedPrimitives(from: template,
                                                 coordinateSystem: coordinateSystem) {
            addPrimitive(primitive)
        }
    }

    /// Turns the template's canonical master into imported path primitives.
    ///
    /// Only the Regular master becomes document geometry. Griddy's model has
    /// one set of primitives shared across masters, with per-master differences
    /// expressed as adjustments (§10.2); importing three unrelated paths as
    /// three sets of primitives would break that identity outright. The other
    /// masters remain available in the preserved source template.
    static func importedPrimitives(from template: SFSymbolTemplate,
                                   coordinateSystem: CoordinateSystem) -> [IconPrimitive] {
        // The same scale the coordinate system was derived from. Taking artwork
        // from a different scale than the metrics places it against the wrong
        // baseline and puts it off canvas.
        let scale = SFSymbolTemplateImporter.canonicalScale(for: template.variants)

        guard let variant = template.variants[
            SymbolSlot(weight: .regular, scale: scale)
        ], !variant.commands.isEmpty else {
            return []
        }

        // Template space has Y increasing downward and its own origin; the
        // document works in units with Y up. Converting here means everything
        // downstream sees one coordinate space.
        let converted = variant.commands.map { command in
            command.mapped { coordinateSystem.iconPoint(from: $0) }
        }

        let points = converted.flatMap { command -> [IconPoint] in
            switch command {
            case .move(let to), .line(let to): [to]
            case .cubic(let c1, let c2, let to): [c1, c2, to]
            case .close: []
            }
        }

        return [.importedPath(ImportedPathPrimitive(
            pathData: SVGPathWriter.write(converted),
            sourceElementID: variant.elementID,
            bounds: PrimitiveGeometry.bounds(containing: points)
        ))]
    }
}

extension SFSymbolTemplateImporter {

    /// Imports a template and builds a document from it in one step.
    public static func importDocument(_ data: Data,
                                      appVersion: String,
                                      author: String? = nil,
                                      now: Date = Date()) throws -> SymbolDocumentPackage {
        let template = try `import`(data)
        let document = SymbolDocument(template: template,
                                      appVersion: appVersion,
                                      author: author,
                                      now: now)

        // The original is kept byte for byte, so anything Griddy does not model
        // survives and the export can be compared against what came in.
        return SymbolDocumentPackage(document: document, sourceTemplate: data)
    }
}
