//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

public enum SVGParseError: Error, Equatable, LocalizedError {

    case notXML
    case noRootElement
    case malformed(String)

    public var errorDescription: String? {
        switch self {
        case .notXML:
            "The file is not valid XML."
        case .noRootElement:
            "The file contains no SVG element."
        case .malformed(let detail):
            "The SVG could not be read: \(detail)"
        }
    }
}

/// Parses SVG into an element tree.
///
/// Uses `XMLParser` rather than regular expressions, per spec 14.1: a template
/// is a structured document and reading it as text would break on the first
/// piece of formatting Apple changes.
public enum SVGParser {

    public static func parse(_ data: Data) throws -> SVGElement {
        let delegate = TreeBuilder()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false

        guard parser.parse() else {
            if let error = delegate.failure {
                throw error
            }
            throw SVGParseError.notXML
        }
        guard let root = delegate.root else {
            throw SVGParseError.noRootElement
        }
        return root
    }

    public static func parse(contentsOf url: URL) throws -> SVGElement {
        try parse(Data(contentsOf: url))
    }
}

/// Builds the element tree as the parser walks the document.
private final class TreeBuilder: NSObject, XMLParserDelegate {

    var root: SVGElement?
    var failure: SVGParseError?

    /// Elements currently open, outermost first.
    private var stack: [SVGElement] = []

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName: String?,
                attributes: [String: String]) {
        stack.append(SVGElement(name: elementName, attributes: attributes))
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard !stack.isEmpty else {
            return
        }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        stack[stack.count - 1].text += stack[stack.count - 1].text.isEmpty
            ? trimmed
            : " " + trimmed
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName: String?) {
        guard let finished = stack.popLast() else {
            return
        }
        if stack.isEmpty {
            root = finished
        } else {
            stack[stack.count - 1].children.append(finished)
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: any Error) {
        failure = .malformed(parseError.localizedDescription)
    }
}
