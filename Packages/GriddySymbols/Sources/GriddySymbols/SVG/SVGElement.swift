//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// A parsed SVG element.
///
/// Deliberately a plain tree rather than a typed SVG model: the importer only
/// needs to find groups by identifier and read a handful of attributes, and
/// keeping everything generic means unrecognised structure is carried along
/// rather than dropped. See spec 14.1.
public struct SVGElement: Hashable, Sendable {

    public var name: String
    public var attributes: [String: String]
    public var children: [SVGElement]

    /// Character data directly inside this element, trimmed.
    public var text: String

    public init(name: String,
                attributes: [String: String] = [:],
                children: [SVGElement] = [],
                text: String = "") {
        self.name = name
        self.attributes = attributes
        self.children = children
        self.text = text
    }

    public var id: String? {
        attributes["id"]
    }

    // MARK: Searching

    /// The first descendant with a given identifier, depth first.
    public func firstDescendant(withID id: String) -> SVGElement? {
        if self.id == id {
            return self
        }
        for child in children {
            if let found = child.firstDescendant(withID: id) {
                return found
            }
        }
        return nil
    }

    /// Every descendant whose identifier satisfies a test.
    public func descendants(where matches: (SVGElement) -> Bool) -> [SVGElement] {
        var found: [SVGElement] = []
        if matches(self) {
            found.append(self)
        }
        for child in children {
            found.append(contentsOf: child.descendants(where: matches))
        }
        return found
    }

    /// All text carried by this element and its descendants, joined.
    ///
    /// SVG puts label text inside nested `tspan` elements, so reading an
    /// element's own character data alone finds nothing.
    public var allText: String {
        ([text] + children.map(\.allText))
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: Attributes

    public func double(_ attribute: String) -> Double? {
        attributes[attribute].flatMap(Double.init)
    }
}
