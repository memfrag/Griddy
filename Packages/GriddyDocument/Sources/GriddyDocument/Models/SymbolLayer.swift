//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

/// An ordered group of primitives with a semantic role.
///
/// Layers own their membership. A primitive does not record which layer it
/// belongs to, so the two can never disagree. See spec 13.4.
public struct SymbolLayer: Codable, Hashable, Sendable, Identifiable {

    public var id: UUID
    public var name: String
    public var role: SymbolLayerRole
    public var primitiveIDs: [PrimitiveID]
    public var isVisible: Bool
    public var isLocked: Bool
    public var renderingRole: SymbolRenderingRole

    public init(id: UUID = UUID(),
                name: String,
                role: SymbolLayerRole,
                primitiveIDs: [PrimitiveID] = [],
                isVisible: Bool = true,
                isLocked: Bool = false,
                renderingRole: SymbolRenderingRole = .monochrome) {
        self.id = id
        self.name = name
        self.role = role
        self.primitiveIDs = primitiveIDs
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.renderingRole = renderingRole
    }
}

public enum SymbolLayerRole: String, Codable, Sendable, CaseIterable {
    case outerBody
    case detail
    case badge
    case cutout
    case annotation
}

/// How a layer participates in SF Symbols rendering modes.
///
/// The MVP is monochrome only. This exists so the architecture is not painted
/// into a corner. See spec 13.4.
public enum SymbolRenderingRole: String, Codable, Sendable, CaseIterable {
    case monochrome
    case hierarchicalPrimary
    case hierarchicalSecondary
    case paletteLayer
    case multicolorLayer
}
