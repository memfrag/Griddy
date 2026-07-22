//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry
import GriddyConstraints

/// One custom SF Symbol.
///
/// A document describes exactly one symbol and holds no references to other
/// documents. Comparison against other symbols uses the system symbol set
/// instead. See spec 13.1.
public struct SymbolDocument: Codable, Hashable, Sendable, Identifiable {

    public var id: UUID
    public var metadata: SymbolMetadata
    public var coordinateSystem: CoordinateSystem
    public var grid: GridDefinition
    public var keyShapes: KeyShapeSet
    public var layers: [SymbolLayer]
    public var primitives: [IconPrimitive]
    public var constraints: [Constraint]
    public var masters: [SymbolMaster]

    /// Per-weight horizontal metrics. Empty means every weight is computed
    /// from its own artwork on export. See ``SymbolMargins``.
    public var margins: SymbolMargins
    public var previewSettings: PreviewSettings
    public var exportSettings: ExportSettings
    public var validationState: ValidationState

    public init(id: UUID = UUID(),
                metadata: SymbolMetadata,
                coordinateSystem: CoordinateSystem,
                grid: GridDefinition,
                keyShapes: KeyShapeSet,
                layers: [SymbolLayer] = [],
                primitives: [IconPrimitive] = [],
                constraints: [Constraint] = [],
                masters: [SymbolMaster] = SymbolMaster.authoredDefaults,
                margins: SymbolMargins = SymbolMargins(),
                previewSettings: PreviewSettings = .default,
                exportSettings: ExportSettings = .default,
                validationState: ValidationState = .empty) {
        self.id = id
        self.metadata = metadata
        self.coordinateSystem = coordinateSystem
        self.grid = grid
        self.keyShapes = keyShapes
        self.layers = layers
        self.primitives = primitives
        self.constraints = constraints
        self.masters = masters
        self.margins = margins
        self.previewSettings = previewSettings
        self.exportSettings = exportSettings
        self.validationState = validationState
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case id, metadata, coordinateSystem, grid, keyShapes, layers
        case primitives, constraints, masters, margins
        case previewSettings, exportSettings, validationState
    }

    /// Decodes documents written before margins were document state.
    ///
    /// Those carry no `margins` key and take the automatic default, which
    /// recomputes every weight from its artwork -- the behaviour they should
    /// have had. Spelled out rather than synthesised only so this one key can
    /// be optional; every other field is still required.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        metadata = try container.decode(SymbolMetadata.self, forKey: .metadata)
        coordinateSystem = try container.decode(
            CoordinateSystem.self, forKey: .coordinateSystem)
        grid = try container.decode(GridDefinition.self, forKey: .grid)
        keyShapes = try container.decode(KeyShapeSet.self, forKey: .keyShapes)
        layers = try container.decode([SymbolLayer].self, forKey: .layers)
        primitives = try container.decode([IconPrimitive].self, forKey: .primitives)
        constraints = try container.decode([Constraint].self, forKey: .constraints)
        masters = try container.decode([SymbolMaster].self, forKey: .masters)
        previewSettings = try container.decode(
            PreviewSettings.self, forKey: .previewSettings)
        exportSettings = try container.decode(
            ExportSettings.self, forKey: .exportSettings)
        validationState = try container.decode(
            ValidationState.self, forKey: .validationState)

        margins = try container.decodeIfPresent(
            SymbolMargins.self, forKey: .margins) ?? SymbolMargins()
    }

    // MARK: Creating

    /// Creates an empty document from template metrics.
    ///
    /// This is the single construction path for both New Symbol and Import
    /// Template: a new document is produced by running the bundled blank
    /// template through the importer, so no document ever lacks a
    /// template-derived coordinate system. See spec 7.1 and 9.1.
    public static func new(name: String,
                           templateMetrics: TemplateMetrics,
                           appVersion: String,
                           author: String? = nil,
                           now: Date = Date()) -> SymbolDocument {
        let coordinateSystem = CoordinateSystem(templateMetrics: templateMetrics)
        return SymbolDocument(
            metadata: SymbolMetadata(name: name,
                                     author: author,
                                     createdAt: now,
                                     modifiedAt: now,
                                     appVersion: appVersion),
            coordinateSystem: coordinateSystem,
            grid: .default(for: coordinateSystem),
            keyShapes: .default(for: coordinateSystem),
            layers: [SymbolLayer(name: "Outer Body", role: .outerBody)]
        )
    }

    // MARK: Accessing primitives

    public func primitive(withID id: PrimitiveID) -> IconPrimitive? {
        primitives.first { $0.id == id }
    }

    /// The primitives belonging to a layer, in the layer's own order.
    ///
    /// Identifiers with no matching primitive are skipped rather than treated
    /// as an error, so a partially-migrated document still renders.
    public func primitives(in layer: SymbolLayer) -> [IconPrimitive] {
        layer.primitiveIDs.compactMap { primitive(withID: $0) }
    }

    /// The constraints governing a primitive.
    public func constraints(for primitiveID: PrimitiveID) -> [Constraint] {
        constraints.filter { $0.affectedPrimitiveIDs.contains(primitiveID) }
    }

    /// The authored master for a weight, if it exists.
    public func master(for weight: SymbolWeight,
                       scale: SymbolScale = .medium) -> SymbolMaster? {
        masters.first { $0.weight == weight && $0.scale == scale }
    }

    // MARK: Integrity

    /// Layer membership entries that do not resolve to a primitive.
    ///
    /// Used by the structural validation tier. See spec 15.3.
    public var danglingPrimitiveIDs: [PrimitiveID] {
        let known = Set(primitives.map(\.id))
        return layers
            .flatMap(\.primitiveIDs)
            .filter { !known.contains($0) }
    }

    /// Primitives that no layer claims.
    public var orphanedPrimitiveIDs: [PrimitiveID] {
        let claimed = Set(layers.flatMap(\.primitiveIDs))
        return primitives.map(\.id).filter { !claimed.contains($0) }
    }
}
