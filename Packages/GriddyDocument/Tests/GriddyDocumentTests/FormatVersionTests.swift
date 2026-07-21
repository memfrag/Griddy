//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
import GriddyGeometry
@testable import GriddyDocument

private func makePackage(formatVersion: Int = DocumentFormatVersion.current,
                         extraFiles: [String: Data] = [:]) throws -> FileWrapper {
    var document = SymbolDocument.new(name: "Test",
                                      templateMetrics: .provisionalBlankTemplate,
                                      appVersion: "1.0.0")
    document.metadata.documentFormatVersion = formatVersion

    let wrapper = try SymbolDocumentPackage(document: document).fileWrapper()

    // Rewrite metadata.json with the requested version, since fileWrapper()
    // always stamps the current version on write.
    if formatVersion != DocumentFormatVersion.current {
        let encoder = SymbolDocumentPackage.makeEncoder()
        let data = try encoder.encode(document.metadata)
        wrapper.removeFileWrapper(wrapper.fileWrappers?["metadata.json"] ?? FileWrapper())
        wrapper.addRegularFile(withContents: data, preferredFilename: "metadata.json")
    }

    for (name, contents) in extraFiles {
        wrapper.addRegularFile(withContents: contents, preferredFilename: name)
    }

    return wrapper
}

@Suite("Format version policy")
struct FormatVersionTests {

    @Test("A current-version document opens")
    func currentVersionOpens() throws {
        let wrapper = try makePackage()
        let package = try SymbolDocumentPackage.read(from: wrapper)
        #expect(package.document.metadata.documentFormatVersion
                == DocumentFormatVersion.current)
    }

    @Test("A document from a newer build is refused, not partially read")
    func newerVersionIsRefused() throws {
        let future = DocumentFormatVersion.current + 1
        let wrapper = try makePackage(formatVersion: future)

        #expect(throws: DocumentPackageError.createdByNewerVersion(
            found: future,
            supported: DocumentFormatVersion.current
        )) {
            try SymbolDocumentPackage.read(from: wrapper)
        }
    }

    @Test("The refusal explains itself and suggests a fix")
    func refusalMessage() {
        let error = DocumentPackageError.createdByNewerVersion(found: 2, supported: 1)
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.recoverySuggestion == "Update Griddy to open it.")
    }

    @Test("A document older than the oldest supported version is refused")
    func tooOldIsRefused() throws {
        let ancient = DocumentFormatVersion.oldestSupported - 1
        let wrapper = try makePackage(formatVersion: ancient)

        #expect(throws: DocumentPackageError.unsupportedLegacyVersion(
            found: ancient,
            oldestSupported: DocumentFormatVersion.oldestSupported
        )) {
            try SymbolDocumentPackage.read(from: wrapper)
        }
    }

    @Test("Version is checked before any other file is parsed")
    func versionCheckedFirst() throws {
        // Corrupt every file except metadata.json. If the version check did not
        // run first, this would fail with a parse error instead of the version
        // error, and a future document would be partially read.
        let wrapper = try makePackage(formatVersion: DocumentFormatVersion.current + 1)
        for name in ["document.json", "geometry.json",
                     "constraints.json", "masters.json"] {
            if let existing = wrapper.fileWrappers?[name] {
                wrapper.removeFileWrapper(existing)
            }
            wrapper.addRegularFile(withContents: Data("not json".utf8),
                                   preferredFilename: name)
        }

        #expect(throws: DocumentPackageError.self) {
            try SymbolDocumentPackage.read(from: wrapper)
        }

        // Confirm it is specifically the version error, not a parse error.
        do {
            _ = try SymbolDocumentPackage.read(from: wrapper)
            Issue.record("Expected the read to throw")
        } catch let error as DocumentPackageError {
            #expect(error == .createdByNewerVersion(
                found: DocumentFormatVersion.current + 1,
                supported: DocumentFormatVersion.current
            ))
        }
    }

    @Test("A missing file is reported by name")
    func missingFile() throws {
        let wrapper = try makePackage()
        if let geometry = wrapper.fileWrappers?["geometry.json"] {
            wrapper.removeFileWrapper(geometry)
        }

        #expect(throws: DocumentPackageError.missingFile("geometry.json")) {
            try SymbolDocumentPackage.read(from: wrapper)
        }
    }

    @Test("A corrupt file is reported by name rather than crashing")
    func corruptFile() throws {
        let wrapper = try makePackage()
        if let geometry = wrapper.fileWrappers?["geometry.json"] {
            wrapper.removeFileWrapper(geometry)
        }
        wrapper.addRegularFile(withContents: Data("{ not valid".utf8),
                               preferredFilename: "geometry.json")

        #expect(throws: DocumentPackageError.unreadableFile("geometry.json")) {
            try SymbolDocumentPackage.read(from: wrapper)
        }
    }

    @Test("A non-package file wrapper is rejected")
    func notAPackage() {
        let wrapper = FileWrapper(regularFileWithContents: Data("nope".utf8))

        #expect(throws: DocumentPackageError.notAPackage) {
            try SymbolDocumentPackage.read(from: wrapper)
        }
    }
}

@Suite("Unknown file preservation")
struct PreservationTests {

    @Test("Files this build does not recognise survive a read/write cycle")
    func unknownFilesSurvive() throws {
        let future = Data(#"{"tracks":[]}"#.utf8)
        let wrapper = try makePackage(extraFiles: ["animation.json": future])

        let package = try SymbolDocumentPackage.read(from: wrapper)
        #expect(package.preservedFiles["animation.json"] == future)

        // The crucial part: writing must put it back, or an older build would
        // silently destroy a newer build's data. See spec 13.1.
        let rewritten = try package.fileWrapper()
        let contents = rewritten.fileWrappers?["animation.json"]?.regularFileContents
        #expect(contents == future)
    }

    @Test("Recognised files are not treated as unknown")
    func knownFilesAreNotPreserved() throws {
        let wrapper = try makePackage()
        let package = try SymbolDocumentPackage.read(from: wrapper)
        #expect(package.preservedFiles.isEmpty)
    }
}

@Suite("Migration")
struct MigrationTests {

    @Test("A current-version package needs no migration")
    func noMigrationNeeded() {
        let document = SymbolDocument.new(name: "Test",
                                          templateMetrics: .provisionalBlankTemplate,
                                          appVersion: "1.0.0")
        let package = SymbolDocumentPackage(document: document)
        #expect(!DocumentMigration.needsMigration(package))
    }

    @Test("There are no migration steps at format version 1")
    func noStepsYet() {
        // Version 1 is the first format, so there is nothing older to migrate
        // from. This test exists to fail loudly when version 2 is introduced
        // without a corresponding step.
        #expect(DocumentMigration.steps.isEmpty)
        #expect(DocumentFormatVersion.current == 1)
    }

    @Test("Version checking accepts the current version")
    func checkVersionAcceptsCurrent() throws {
        try DocumentMigration.checkVersion(DocumentFormatVersion.current)
    }
}
