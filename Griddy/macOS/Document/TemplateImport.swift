//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers
import GriddyDocument
import GriddySymbols

/// Loading SF Symbols templates from the app.
enum TemplateImport {

    /// The bundled blank template a new document starts from.
    ///
    /// New Symbol and Import Template deliberately share one code path: the
    /// blank template is parsed by the same importer as any other file, so a
    /// new document's coordinate system is template-derived rather than
    /// synthesised. See spec 7.1.
    static func blankTemplateData() -> Data? {
        guard let url = Bundle.main.url(forResource: "BlankSymbolTemplate",
                                        withExtension: "svg") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    /// A package for a brand new document.
    ///
    /// Falls back to constructing the document directly if the bundled
    /// template is missing or unreadable. A missing resource should not stop
    /// someone starting work, and the fallback metrics are measured from the
    /// same template.
    static func newDocumentPackage() -> SymbolDocumentPackage {
        if let data = blankTemplateData(),
           let package = try? SFSymbolTemplateImporter.importDocument(
                data, appVersion: Bundle.main.appVersionString) {
            var package = package
            package.document.metadata.name = "Untitled"
            return package
        }

        return SymbolDocumentPackage(document: .new(
            name: "Untitled",
            templateMetrics: .blankTemplate,
            appVersion: Bundle.main.appVersionString
        ))
    }
}

/// Presents the outcome of an import attempt.
///
/// A refusal has to explain itself and say what to do, or the strictness in
/// spec 14.1 just reads as the app being broken.
struct ImportFailure: Identifiable {

    let id = UUID()
    var title: String
    var message: String
    var suggestion: String?

    init(_ error: any Error) {
        if let error = error as? TemplateImportError {
            title = "Griddy can't open this template."
            message = error.errorDescription ?? String(describing: error)
            suggestion = error.recoverySuggestion
        } else if let error = error as? SVGParseError {
            title = "Griddy can't read this file."
            message = error.errorDescription ?? String(describing: error)
            suggestion = "Check that the file is an SVG exported from the "
                + "SF Symbols app."
        } else {
            title = "Import failed."
            message = error.localizedDescription
            suggestion = nil
        }
    }
}
