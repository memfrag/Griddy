//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers
import GriddyDocument
import GriddyGeometry

extension UTType {

    /// The `.griddy` document package type, declared in Info.plist.
    nonisolated static let griddySymbol = UTType(exportedAs: "pizza.martin.griddy.symbol")
}

/// Thread-safe storage for the document package.
///
/// Exists because SwiftUI serialises documents off the main actor: autosave
/// calls `snapshot(contentType:)` from a background dispatch queue while the
/// UI reads and writes the same value on the main actor.
private nonisolated final class PackageStorage: @unchecked Sendable {

    private let lock = NSLock()
    nonisolated(unsafe) private var storedValue: SymbolDocumentPackage

    init(_ value: SymbolDocumentPackage) {
        storedValue = value
    }

    var value: SymbolDocumentPackage {
        get { lock.withLock { storedValue } }
        set { lock.withLock { storedValue = newValue } }
    }
}

/// The SwiftUI document wrapper around a ``SymbolDocumentPackage``.
///
/// This is a `ReferenceFileDocument` rather than a `FileDocument` because edits
/// are semantic commands registered with an `UndoManager`, and gesture-scoped
/// undo grouping needs a stable reference to register against. See spec 16.4.
///
/// **Isolation.** The app target builds with
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, which suits the observable
/// state this class publishes to the UI. But `ReferenceFileDocument` requires
/// `Sendable` and SwiftUI calls **both** serialisation entry points off the
/// main actor during autosave -- `snapshot(contentType:)` as well as
/// `fileWrapper(snapshot:configuration:)`. Every protocol requirement is
/// therefore explicitly `nonisolated`, and the package lives behind a lock so
/// those off-main reads are safe.
///
/// Do not "simplify" this by dropping `nonisolated` and relying on a
/// `@preconcurrency` conformance instead: that compiles, runs fine until the
/// document is first edited, and then traps inside `snapshot(contentType:)` on
/// `com.apple.root.default-qos` the moment autosave fires.
@MainActor
final class SymbolDocumentFile: ReferenceFileDocument {

    typealias Snapshot = SymbolDocumentPackage

    nonisolated static let readableContentTypes: [UTType] = [.griddySymbol]
    nonisolated static let writableContentTypes: [UTType] = [.griddySymbol]

    private let storage: PackageStorage

    /// Bumped every time an undo step is registered.
    ///
    /// Exists so views can depend on the undo stack changing. `UndoManager` is
    /// not observable, and registering a step does not necessarily mutate the
    /// document -- committing a drag registers undo without changing anything,
    /// because the drag already applied its edits. Without this, anything
    /// derived from the undo stack would be captured before registration and
    /// then stay stale.
    @Published private(set) var undoRevision: Int = 0

    func noteUndoStackChanged() {
        undoRevision &+= 1
    }

    /// The document package.
    ///
    /// Backed by lock-protected storage rather than `@Published`, so it can be
    /// read from the serialisation queue. Change notification is published
    /// manually on write.
    var package: SymbolDocumentPackage {
        get { storage.value }
        set {
            objectWillChange.send()
            storage.value = newValue
        }
    }

    var document: SymbolDocument {
        get { package.document }
        set { package.document = newValue }
    }

    /// Creates an empty document.
    ///
    /// New Symbol and Import Template share one path: the bundled blank
    /// template goes through the same importer as any other file, so the
    /// coordinate system is always template-derived rather than synthesised.
    /// See spec 7.1.
    init() {
        storage = PackageStorage(TemplateImport.newDocumentPackage())
    }

    /// Replaces this document's contents with an imported template.
    ///
    /// Importing into the open document rather than opening a second one keeps
    /// the undo stack meaningful: the import is an edit, and one undo puts the
    /// previous work back.
    func replaceContents(with package: SymbolDocumentPackage,
                         undoManager: UndoManager?) {
        let before = self.package
        self.package = package
        undoManager?.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated {
                target.replaceContents(with: before, undoManager: undoManager)
            }
        }
        undoManager?.setActionName("Import Template")
        noteUndoStackChanged()
    }

    nonisolated init(configuration: ReadConfiguration) throws {
        storage = PackageStorage(try SymbolDocumentPackage.read(from: configuration.file))
    }

    /// Captures the state to serialise.
    ///
    /// Called off the main actor during autosave.
    nonisolated func snapshot(contentType: UTType) throws -> SymbolDocumentPackage {
        storage.value
    }

    /// Serialises a snapshot.
    ///
    /// Touches only its parameters, which is what makes running this off the
    /// main actor safe.
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
