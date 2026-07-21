//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry
import GriddyConstraints

/// A `.griddy` document package.
///
/// The package is a directory rather than a single file, split so that the
/// format version can be read without parsing anything else. See spec 13.1.
///
///     MySymbol.griddy/
///       metadata.json        <- read first, carries documentFormatVersion
///       document.json
///       geometry.json
///       constraints.json
///       masters.json
///       source-template.svg
///       previews/
///       exports/
public struct SymbolDocumentPackage: Sendable {

    public var document: SymbolDocument

    /// The template this document was imported from, preserved byte for byte.
    ///
    /// Griddy never rewrites it. See spec 14.1.
    public var sourceTemplate: Data?

    /// Files found in the package that this build does not recognise.
    ///
    /// Preserved verbatim and written back unchanged, so a document touched by
    /// a newer Griddy does not lose that version's data when an older build
    /// opens it. See spec 13.1.
    public var preservedFiles: [String: Data]

    public init(document: SymbolDocument,
                sourceTemplate: Data? = nil,
                preservedFiles: [String: Data] = [:]) {
        self.document = document
        self.sourceTemplate = sourceTemplate
        self.preservedFiles = preservedFiles
    }
}

// MARK: - File names

extension SymbolDocumentPackage {

    enum FileName {
        static let metadata = "metadata.json"
        static let document = "document.json"
        static let geometry = "geometry.json"
        static let constraints = "constraints.json"
        static let masters = "masters.json"
        static let sourceTemplate = "source-template.svg"
        static let previews = "previews"
        static let exports = "exports"

        /// Files this build writes. Anything else found in a package is
        /// preserved rather than dropped.
        static let known: Set<String> = [
            metadata, document, geometry, constraints, masters,
            sourceTemplate, previews, exports
        ]
    }
}

// MARK: - On-disk payloads

/// Split payloads, one per file in the package.
///
/// These exist so the encoded layout is stable and hand-inspectable, and so
/// the version can be read on its own.
extension SymbolDocumentPackage {

    struct DocumentPayload: Codable {
        var id: UUID
        var coordinateSystem: CoordinateSystem
        var grid: GridDefinition
        var keyShapes: KeyShapeSet
        var previewSettings: PreviewSettings
        var exportSettings: ExportSettings
        var validationState: ValidationState
    }

    struct GeometryPayload: Codable {
        var layers: [SymbolLayer]
        var primitives: [IconPrimitive]
    }

    struct ConstraintsPayload: Codable {
        var constraints: [Constraint]
    }

    struct MastersPayload: Codable {
        var masters: [SymbolMaster]
    }
}

// MARK: - Coders

extension SymbolDocumentPackage {

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

// MARK: - Errors

public enum DocumentPackageError: Error, Equatable, LocalizedError {

    case notAPackage
    case missingFile(String)
    case unreadableFile(String)

    /// The document was written by a newer build.
    ///
    /// Refused rather than partially read: showing a designer a document that
    /// cannot be fully understood is worse than not opening it. See spec 13.3.
    case createdByNewerVersion(found: Int, supported: Int)

    case unsupportedLegacyVersion(found: Int, oldestSupported: Int)

    public var errorDescription: String? {
        switch self {
        case .notAPackage:
            "This is not a Griddy document."
        case .missingFile(let name):
            "The document is missing its \(name) file."
        case .unreadableFile(let name):
            "The document's \(name) file could not be read."
        case .createdByNewerVersion:
            "This document was created by a newer version of Griddy."
        case .unsupportedLegacyVersion(let found, let oldest):
            "This document uses format version \(found). "
                + "The oldest supported version is \(oldest)."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .createdByNewerVersion:
            "Update Griddy to open it."
        default:
            nil
        }
    }
}
