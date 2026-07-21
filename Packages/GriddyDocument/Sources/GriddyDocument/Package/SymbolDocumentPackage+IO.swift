//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry
import GriddyConstraints

extension SymbolDocumentPackage {

    // MARK: Reading

    /// Reads a package, migrating it forward if it was written by an older
    /// build and refusing it if written by a newer one. See spec 13.3.
    public static func read(from wrapper: FileWrapper) throws -> SymbolDocumentPackage {
        guard wrapper.isDirectory, let files = wrapper.fileWrappers else {
            throw DocumentPackageError.notAPackage
        }

        let decoder = makeDecoder()

        // Metadata is read first and on its own, so a document from the future
        // is refused before any other parsing is attempted.
        let metadataData = try data(named: FileName.metadata, in: files)
        let metadata = try decode(SymbolMetadata.self,
                                  from: metadataData,
                                  named: FileName.metadata,
                                  using: decoder)

        try DocumentMigration.checkVersion(metadata.documentFormatVersion)

        let documentData = try data(named: FileName.document, in: files)
        let geometryData = try data(named: FileName.geometry, in: files)
        let constraintsData = try data(named: FileName.constraints, in: files)
        let mastersData = try data(named: FileName.masters, in: files)

        let documentPayload = try decode(DocumentPayload.self,
                                         from: documentData,
                                         named: FileName.document,
                                         using: decoder)
        let geometryPayload = try decode(GeometryPayload.self,
                                         from: geometryData,
                                         named: FileName.geometry,
                                         using: decoder)
        let constraintsPayload = try decode(ConstraintsPayload.self,
                                            from: constraintsData,
                                            named: FileName.constraints,
                                            using: decoder)
        let mastersPayload = try decode(MastersPayload.self,
                                        from: mastersData,
                                        named: FileName.masters,
                                        using: decoder)

        let document = SymbolDocument(
            id: documentPayload.id,
            metadata: metadata,
            coordinateSystem: documentPayload.coordinateSystem,
            grid: documentPayload.grid,
            keyShapes: documentPayload.keyShapes,
            layers: geometryPayload.layers,
            primitives: geometryPayload.primitives,
            constraints: constraintsPayload.constraints,
            masters: mastersPayload.masters,
            previewSettings: documentPayload.previewSettings,
            exportSettings: documentPayload.exportSettings,
            validationState: documentPayload.validationState
        )

        let sourceTemplate = files[FileName.sourceTemplate]?.regularFileContents

        // Anything this build does not recognise is carried through untouched.
        var preserved: [String: Data] = [:]
        for (name, file) in files where !FileName.known.contains(name) {
            if let contents = file.regularFileContents {
                preserved[name] = contents
            }
        }

        let package = SymbolDocumentPackage(document: document,
                                            sourceTemplate: sourceTemplate,
                                            preservedFiles: preserved)

        return DocumentMigration.migrate(package)
    }

    // MARK: Writing

    public func fileWrapper() throws -> FileWrapper {
        let encoder = Self.makeEncoder()

        var metadata = document.metadata
        metadata.documentFormatVersion = DocumentFormatVersion.current

        let documentPayload = DocumentPayload(
            id: document.id,
            coordinateSystem: document.coordinateSystem,
            grid: document.grid,
            keyShapes: document.keyShapes,
            previewSettings: document.previewSettings,
            exportSettings: document.exportSettings,
            validationState: document.validationState
        )
        let geometryPayload = GeometryPayload(layers: document.layers,
                                              primitives: document.primitives)
        let constraintsPayload = ConstraintsPayload(constraints: document.constraints)
        let mastersPayload = MastersPayload(masters: document.masters)

        var files: [String: FileWrapper] = [
            FileName.metadata: FileWrapper(regularFileWithContents:
                try encoder.encode(metadata)),
            FileName.document: FileWrapper(regularFileWithContents:
                try encoder.encode(documentPayload)),
            FileName.geometry: FileWrapper(regularFileWithContents:
                try encoder.encode(geometryPayload)),
            FileName.constraints: FileWrapper(regularFileWithContents:
                try encoder.encode(constraintsPayload)),
            FileName.masters: FileWrapper(regularFileWithContents:
                try encoder.encode(mastersPayload))
        ]

        if let sourceTemplate {
            files[FileName.sourceTemplate] =
                FileWrapper(regularFileWithContents: sourceTemplate)
        }

        for (name, contents) in preservedFiles {
            files[name] = FileWrapper(regularFileWithContents: contents)
        }

        return FileWrapper(directoryWithFileWrappers: files)
    }

    // MARK: Helpers

    private static func data(named name: String,
                             in files: [String: FileWrapper]) throws -> Data {
        guard let file = files[name] else {
            throw DocumentPackageError.missingFile(name)
        }
        guard let contents = file.regularFileContents else {
            throw DocumentPackageError.unreadableFile(name)
        }
        return contents
    }

    private static func decode<T: Decodable>(_ type: T.Type,
                                             from data: Data,
                                             named name: String,
                                             using decoder: JSONDecoder) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw DocumentPackageError.unreadableFile(name)
        }
    }
}
