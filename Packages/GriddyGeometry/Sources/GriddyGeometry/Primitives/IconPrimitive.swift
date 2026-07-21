//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// A semantic geometry object.
///
/// Griddy models artwork as primitives rather than arbitrary paths, so the
/// document stores the intent behind a shape and not only its outline. See
/// spec 6.1 and 10.1.
public enum IconPrimitive: Codable, Hashable, Sendable, Identifiable {

    case line(LinePrimitive)
    case arc(ArcPrimitive)
    case circle(CirclePrimitive)
    case roundedRect(RoundedRectPrimitive)
    case capsule(CapsulePrimitive)
    case polyline(PolylinePrimitive)
    case symmetricPath(SymmetricPathPrimitive)
    case compound(CompoundPrimitive)
    case importedPath(ImportedPathPrimitive)

    public var id: PrimitiveID {
        switch self {
        case .line(let primitive): primitive.id
        case .arc(let primitive): primitive.id
        case .circle(let primitive): primitive.id
        case .roundedRect(let primitive): primitive.id
        case .capsule(let primitive): primitive.id
        case .polyline(let primitive): primitive.id
        case .symmetricPath(let primitive): primitive.id
        case .compound(let primitive): primitive.id
        case .importedPath(let primitive): primitive.id
        }
    }

    public var attributes: PrimitiveAttributes {
        get {
            switch self {
            case .line(let primitive): primitive.attributes
            case .arc(let primitive): primitive.attributes
            case .circle(let primitive): primitive.attributes
            case .roundedRect(let primitive): primitive.attributes
            case .capsule(let primitive): primitive.attributes
            case .polyline(let primitive): primitive.attributes
            case .symmetricPath(let primitive): primitive.attributes
            case .compound(let primitive): primitive.attributes
            case .importedPath(let primitive): primitive.attributes
            }
        }
        set {
            switch self {
            case .line(var primitive):
                primitive.attributes = newValue
                self = .line(primitive)
            case .arc(var primitive):
                primitive.attributes = newValue
                self = .arc(primitive)
            case .circle(var primitive):
                primitive.attributes = newValue
                self = .circle(primitive)
            case .roundedRect(var primitive):
                primitive.attributes = newValue
                self = .roundedRect(primitive)
            case .capsule(var primitive):
                primitive.attributes = newValue
                self = .capsule(primitive)
            case .polyline(var primitive):
                primitive.attributes = newValue
                self = .polyline(primitive)
            case .symmetricPath(var primitive):
                primitive.attributes = newValue
                self = .symmetricPath(primitive)
            case .compound(var primitive):
                primitive.attributes = newValue
                self = .compound(primitive)
            case .importedPath(var primitive):
                primitive.attributes = newValue
                self = .importedPath(primitive)
            }
        }
    }

    /// Whether this primitive carries editable semantic properties.
    ///
    /// Imported fallback paths render and export faithfully but expose no
    /// semantic geometry until the user converts them. See spec 14.3.
    public var isSemantic: Bool {
        if case .importedPath = self {
            return false
        }
        return true
    }

    /// A short human-readable kind, used in the inspector and in undo action
    /// names.
    public var kindName: String {
        switch self {
        case .line: "Line"
        case .arc: "Arc"
        case .circle: "Circle"
        case .roundedRect: "Rounded Rectangle"
        case .capsule: "Capsule"
        case .polyline: "Polyline"
        case .symmetricPath: "Symmetric Path"
        case .compound: "Compound"
        case .importedPath: "Imported Path"
        }
    }
}
