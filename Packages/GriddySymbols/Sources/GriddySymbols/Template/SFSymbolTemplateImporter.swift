//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

public enum TemplateImportError: Error, Equatable, LocalizedError {

    case missingGroup(String)
    case missingGuide(String)
    case unsupportedVersion(found: String, supported: String)
    case noVariants
    case degenerateMetrics

    public var errorDescription: String? {
        switch self {
        case .missingGroup(let name):
            "This does not look like an SF Symbols template: "
                + "the \(name) group is missing."
        case .missingGuide(let name):
            "The template is missing its \(name) guide."
        case .unsupportedVersion(let found, let supported):
            "This template is version \(found). Griddy supports \(supported)."
        case .noVariants:
            "The template contains no symbol artwork slots."
        case .degenerateMetrics:
            "The template's baseline and capline coincide, "
                + "so no coordinate system can be derived."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .unsupportedVersion:
            "Re-export the template from a current version of the "
                + "SF Symbols app."
        default:
            nil
        }
    }
}

/// Reads SF Symbols templates.
///
/// Griddy targets one template generation and refuses others, rather than
/// adapting to several. That keeps the importer strict, the error messages
/// sharp, and the exporter free of version branches. See spec 14.1.
public enum SFSymbolTemplateImporter {

    /// The template generation Griddy reads and writes.
    public static let supportedVersion = "7.0"

    public static func `import`(_ data: Data) throws -> SFSymbolTemplate {
        let root = try SVGParser.parse(data)

        // Both groups are captured with the transform accumulated from their
        // ancestors. Templates nest them inside wrapper groups that carry
        // transforms of their own, and losing those puts every coordinate --
        // artwork and guides alike -- in the wrong place.
        var symbols: (element: SVGElement, transform: SVGTransform)?
        var guides: (element: SVGElement, transform: SVGTransform)?

        root.walk { element, transform in
            switch element.id {
            case "Symbols" where symbols == nil:
                symbols = (element, transform)
            case "Guides" where guides == nil:
                guides = (element, transform)
            default:
                break
            }
        }

        guard let symbols else {
            throw TemplateImportError.missingGroup("Symbols")
        }
        guard let guides else {
            throw TemplateImportError.missingGroup("Guides")
        }

        let version = try version(in: root)
        let variants = try variants(in: symbols.element, inherited: symbols.transform)
        let metrics = try metrics(in: guides.element,
                                  inherited: guides.transform,
                                  variants: variants)

        // Three slots is the authoring template the SF Symbols app hands you to
        // draw a custom symbol; 27 is a static export of an existing one.
        let kind: SFSymbolTemplate.Kind =
            variants.count > SymbolWeight.authored.count ? .populated : .authoring

        return SFSymbolTemplate(
            name: symbolName(in: root),
            version: version,
            metrics: metrics,
            variants: variants,
            source: data,
            kind: kind
        )
    }

    // MARK: Version

    /// The template generation, read from the Notes group.
    ///
    /// The version is printed as display text rather than carried in an
    /// attribute, so this reads the label Apple writes: "Template v.7.0".
    static func version(in root: SVGElement) throws -> String {
        let labels = root.descendants { $0.id == "template-version" }
            .map(\.allText)

        // A static export carries the same label inside an XML comment rather
        // than as an element, which the parser does not surface. Absence is
        // therefore not proof of an unsupported file.
        guard let label = labels.first else {
            return supportedVersion
        }

        guard let match = label.range(of: #"[0-9]+\.[0-9]+"#, options: .regularExpression)
        else {
            throw TemplateImportError.unsupportedVersion(found: label,
                                                         supported: supportedVersion)
        }

        let found = String(label[match])
        guard found == supportedVersion else {
            throw TemplateImportError.unsupportedVersion(found: found,
                                                         supported: supportedVersion)
        }
        return found
    }

    /// Groups that are template structure rather than the symbol itself.
    private static let structuralGroupIDs: Set<String> = [
        "Notes", "Guides", "Symbols", "Group", "Margins"
    ]

    private static func symbolName(in root: SVGElement) -> String {
        if let title = root.children.first(where: { $0.name == "title" })?.allText,
           !title.isEmpty {
            return title
        }

        // The authoring template wraps everything in a group named after the
        // symbol. A static export has no such wrapper, so the first group is
        // "Notes" -- naming a document after it would be plainly wrong, and is
        // what happened before this check existed.
        if let named = root.children.first(where: {
            $0.name == "g" && $0.id.map { !structuralGroupIDs.contains($0) } == true
        })?.id {
            return named
        }

        return "Untitled"
    }

    /// The scale the document is built from.
    ///
    /// Metrics and artwork must come from the *same* scale: deriving the
    /// coordinate system from the Medium guides and then importing the Small
    /// artwork places the geometry against the wrong baseline and puts it off
    /// canvas entirely.
    static func canonicalScale(for variants: [SymbolSlot: SFSymbolVariant]) -> SymbolScale {
        let populated = variants.filter { !$0.value.commands.isEmpty }
        let scales = Set((populated.isEmpty ? variants : populated).keys.map(\.scale))

        // Prefer Medium when the template offers it; an authoring template only
        // has Small, which is then the only honest choice.
        if scales.contains(.medium) { return .medium }
        if scales.contains(.small) { return .small }
        return scales.first ?? .small
    }

    // MARK: Variants

    static func variants(in symbols: SVGElement,
                         inherited: SVGTransform = .identity)
    throws -> [SymbolSlot: SFSymbolVariant] {
        var found: [SymbolSlot: SFSymbolVariant] = [:]

        symbols.walk(withEffectiveTransform: inherited) { element, transform in
            guard let id = element.id, let slot = slot(fromElementID: id) else {
                return
            }

            // Every path in the group, not just the first, and each carrying
            // its own accumulated transform: templates position variants with
            // a group transform and keep the path data in local coordinates,
            // so untransformed data lands nowhere near the canvas.
            var commands: [SVGPathCommand] = []
            element.walk(withEffectiveTransform: transform) { child, childTransform in
                guard child.name == "path", let data = child.attributes["d"],
                      let parsed = try? SVGPathData.parse(data) else {
                    return
                }
                commands.append(contentsOf: parsed.map { command in
                    command.mapped { childTransform.apply(to: $0) }
                })
            }

            // An empty slot is meaningful, not a failure: a blank template has
            // the slot groups in place with no artwork in them, and that is
            // exactly what a new document starts from. See spec 7.1.
            found[slot] = SFSymbolVariant(
                slot: slot,
                elementID: id,
                pathData: SVGPathWriter.write(commands),
                commands: commands
            )
        }

        // What must be present is the slots themselves. A file with no slot
        // groups at all is not a symbol template.
        guard !found.isEmpty else {
            throw TemplateImportError.noVariants
        }
        return found
    }

    /// Parses an identifier such as `Regular-S` into a slot.
    static func slot(fromElementID id: String) -> SymbolSlot? {
        let parts = id.split(separator: "-")
        guard parts.count == 2,
              let weight = SymbolWeight(rawValue: parts[0].lowercased()),
              let scale = scale(fromSuffix: String(parts[1])) else {
            return nil
        }
        return SymbolSlot(weight: weight, scale: scale)
    }

    private static func scale(fromSuffix suffix: String) -> SymbolScale? {
        switch suffix.uppercased() {
        case "S": .small
        case "M": .medium
        case "L": .large
        default: nil
        }
    }

    // MARK: Metrics

    static func metrics(in guides: SVGElement,
                        inherited: SVGTransform,
                        variants: [SymbolSlot: SFSymbolVariant]) throws -> TemplateMetrics {
        // Same scale the artwork is taken from, or the geometry lands against
        // the wrong baseline.
        let suffix = scaleSuffix(canonicalScale(for: variants))

        guard let baseline = guideY(in: guides, id: "Baseline-\(suffix)",
                                    inherited: inherited) else {
            throw TemplateImportError.missingGuide("Baseline-\(suffix)")
        }
        guard let capline = guideY(in: guides, id: "Capline-\(suffix)",
                                   inherited: inherited) else {
            throw TemplateImportError.missingGuide("Capline-\(suffix)")
        }
        let capHeightSpan = abs(baseline - capline)
        guard capHeightSpan > 1e-9 else {
            throw TemplateImportError.degenerateMetrics
        }

        // The margin belongs to the specific slot the artwork comes from. The
        // template lays the masters out side by side, so each has its own
        // horizontal origin; taking the leftmost across all of them would
        // offset the artwork by the distance between two masters.
        let leftMargin = marginX(in: guides, edge: "left",
                                 suffix: suffix, inherited: inherited) ?? 0
        let rightMargin = marginX(in: guides, edge: "right",
                                  suffix: suffix, inherited: inherited)
            ?? leftMargin + capHeightSpan

        return TemplateMetrics(
            baselineY: baseline,
            caplineY: capline,
            leftMarginX: leftMargin,
            rightMarginX: rightMargin,
            alignmentRects: alignmentRects(in: guides, inherited: inherited)
        )
    }

    static func scaleSuffix(_ scale: SymbolScale) -> String {
        switch scale {
        case .small: "S"
        case .medium: "M"
        case .large: "L"
        }
    }

    /// A guide line's Y position in template space.
    ///
    /// Guides sit inside transformed groups just as artwork does, so the raw
    /// `y1` attribute is a local coordinate. Reading it directly gives a
    /// baseline in the wrong place, and every coordinate derived from it is
    /// then wrong by the same amount.
    static func guideY(in guides: SVGElement,
                       id: String,
                       inherited: SVGTransform = .identity) -> Double? {
        var result: Double?
        guides.walk(withEffectiveTransform: inherited) { element, transform in
            guard result == nil, element.id == id,
                  let x = element.double("x1"), let y = element.double("y1") else {
                return
            }
            result = transform.apply(to: IconPoint(x: x, y: y)).y
        }
        return result
    }

    /// A guide line's X position in template space.
    static func guideX(in guides: SVGElement,
                       id: String,
                       inherited: SVGTransform = .identity) -> Double? {
        var result: Double?
        guides.walk(withEffectiveTransform: inherited) { element, transform in
            guard result == nil, element.id == id,
                  let x = element.double("x1"), let y = element.double("y1") else {
                return
            }
            result = transform.apply(to: IconPoint(x: x, y: y)).x
        }
        return result
    }

    /// The margin guide belonging to the Regular master at a given scale.
    ///
    /// Falls back to any margin at that scale, then to any margin at all, so a
    /// template that annotates a different master still yields an origin.
    static func marginX(in guides: SVGElement,
                        edge: String,
                        suffix: String,
                        inherited: SVGTransform) -> Double? {
        if let exact = guideX(in: guides,
                              id: "\(edge)-margin-Regular-\(suffix)",
                              inherited: inherited) {
            return exact
        }

        var candidates: [Double] = []
        guides.walk(withEffectiveTransform: inherited) { element, transform in
            guard let id = element.id,
                  id.hasPrefix("\(edge)-margin-"),
                  id.hasSuffix("-\(suffix)"),
                  let x = element.double("x1"), let y = element.double("y1") else {
                return
            }
            candidates.append(transform.apply(to: IconPoint(x: x, y: y)).x)
        }

        guard !candidates.isEmpty else {
            return nil
        }
        return edge == "left" ? candidates.min() : candidates.max()
    }

    private static func alignmentRects(in guides: SVGElement,
                                       inherited: SVGTransform)
    -> [SymbolScale: TemplateRect] {
        var rects: [SymbolScale: TemplateRect] = [:]

        for scale in SymbolScale.allCases {
            let suffix = scaleSuffix(scale)
            guard let baseline = guideY(in: guides, id: "Baseline-\(suffix)",
                                        inherited: inherited),
                  let capline = guideY(in: guides, id: "Capline-\(suffix)",
                                       inherited: inherited) else {
                continue
            }
            let left = marginX(in: guides, edge: "left",
                               suffix: suffix, inherited: inherited) ?? 0
            let right = marginX(in: guides, edge: "right",
                                suffix: suffix, inherited: inherited) ?? left
            rects[scale] = TemplateRect(x: left,
                                        y: min(baseline, capline),
                                        width: max(0, right - left),
                                        height: abs(baseline - capline))
        }
        return rects
    }
}
