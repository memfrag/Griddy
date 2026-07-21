//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers
import GriddyDocument
import GriddyGeometry

extension UTType {

    /// The `.griddy` document package type, declared in Info.plist.
    ///
    /// Marked `nonisolated` so the document type is reachable from the
    /// non-isolated save path below.
    nonisolated static let griddySymbol = UTType(exportedAs: "pizza.martin.griddy.symbol")
}

/// The SwiftUI document wrapper around a ``SymbolDocumentPackage``.
///
/// This is a `ReferenceFileDocument` rather than a `FileDocument` because edits
/// are semantic commands registered with an `UndoManager`, and gesture-scoped
/// undo grouping needs a stable reference to register against. See spec 16.4.
///
/// Isolation is worth explaining. The app target builds with
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so this class is main-actor
/// isolated, which is what the document's observable state wants. But
/// `ReferenceFileDocument` is a `@preconcurrency` protocol that also requires
/// `Sendable`, because SwiftUI takes a snapshot on the main actor and may then
/// serialise it elsewhere. The split below reflects that split exactly:
/// ``snapshot(contentType:)`` reads `self` and stays isolated, while
/// ``fileWrapper(snapshot:configuration:)`` touches only its parameters and is
/// explicitly `nonisolated`.
@MainActor
final class SymbolDocumentFile: @preconcurrency ReferenceFileDocument {

    typealias Snapshot = SymbolDocumentPackage

    nonisolated static let readableContentTypes: [UTType] = [.griddySymbol]
    nonisolated static let writableContentTypes: [UTType] = [.griddySymbol]

    @Published var package: SymbolDocumentPackage

    var document: SymbolDocument {
        get { package.document }
        set { package.document = newValue }
    }

    /// Creates an empty document.
    ///
    /// New Symbol and Import Template share one path: the coordinate system is
    /// always template-derived, never synthesised. See spec 7.1.
    init() {
        let document = SymbolDocument.new(
            name: "Untitled",
            templateMetrics: .provisionalBlankTemplate,
            appVersion: Bundle.main.appVersionString
        )
        self.package = SymbolDocumentPackage(document: document)
    }

    init(configuration: ReadConfiguration) throws {
        package = try SymbolDocumentPackage.read(from: configuration.file)
    }

    func snapshot(contentType: UTType) throws -> SymbolDocumentPackage {
        package
    }

    /// Serialises a snapshot.
    ///
    /// Deliberately touches nothing on `self`, which is what makes running this
    /// off the main actor safe.
    nonisolated func fileWrapper(snapshot: SymbolDocumentPackage,
                                 configuration: WriteConfiguration) throws -> FileWrapper {
        var snapshot = snapshot
        snapshot.document.metadata.modifiedAt = Date()
        return try snapshot.fileWrapper()
    }
}

extension Bundle {

    /// The marketing version, used to stamp documents with the writing build.
    nonisolated var appVersionString: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }
}
