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

        guard let symbolsGroup = root.firstDescendant(withID: "Symbols") else {
            throw TemplateImportError.missingGroup("Symbols")
        }
        guard let guidesGroup = root.firstDescendant(withID: "Guides") else {
            throw TemplateImportError.missingGroup("Guides")
        }

        let version = try version(in: root)
        let variants = try variants(in: symbolsGroup)
        let metrics = try metrics(in: guidesGroup, variants: variants)

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

    private static func symbolName(in root: SVGElement) -> String {
        root.children.first { $0.name == "title" }?.allText
            ?? root.children.first { $0.name == "g" }?.id
            ?? "Untitled"
    }

    // MARK: Variants

    static func variants(in symbols: SVGElement) throws -> [SymbolSlot: SFSymbolVariant] {
        var found: [SymbolSlot: SFSymbolVariant] = [:]

        for element in symbols.descendants(where: { $0.name == "g" }) {
            guard let id = element.id, let slot = slot(fromElementID: id) else {
                continue
            }
            guard let path = element.descendants(where: { $0.name == "path" }).first,
                  let data = path.attributes["d"] else {
                continue
            }

            found[slot] = SFSymbolVariant(
                slot: slot,
                elementID: id,
                pathData: data,
                commands: (try? SVGPathData.parse(data)) ?? []
            )
        }

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
                        variants: [SymbolSlot: SFSymbolVariant]) throws -> TemplateMetrics {
        // Derive from the scale the artwork actually occupies. An authoring
        // template holds its masters at Small; a populated one has all three.
        let scale = variants.keys.map(\.scale).contains(.medium) ? "M" : "S"

        guard let baseline = guideY(in: guides, id: "Baseline-\(scale)") else {
            throw TemplateImportError.missingGuide("Baseline-\(scale)")
        }
        guard let capline = guideY(in: guides, id: "Capline-\(scale)") else {
            throw TemplateImportError.missingGuide("Capline-\(scale)")
        }
        guard abs(baseline - capline) > 1e-9 else {
            throw TemplateImportError.degenerateMetrics
        }

        let leftMargin = marginX(in: guides, edge: "left")
            ?? guides.descendants { $0.name == "line" }
                .compactMap { $0.double("x1") }.min()
            ?? 0

        return TemplateMetrics(
            baselineY: baseline,
            caplineY: capline,
            leftMarginX: leftMargin,
            alignmentRects: alignmentRects(in: guides)
        )
    }

    private static func guideY(in guides: SVGElement, id: String) -> Double? {
        guides.firstDescendant(withID: id)?.double("y1")
    }

    /// The margin guide for whichever slot the template happens to annotate.
    ///
    /// An authoring template marks margins for each authored master; a static
    /// export marks only one. Taking the leftmost avoids depending on which.
    private static func marginX(in guides: SVGElement, edge: String) -> Double? {
        let candidates = guides
            .descendants { $0.id?.hasPrefix("\(edge)-margin-") == true }
            .compactMap { $0.double("x1") }
        return edge == "left" ? candidates.min() : candidates.max()
    }

    private static func alignmentRects(in guides: SVGElement) -> [SymbolScale: TemplateRect] {
        var rects: [SymbolScale: TemplateRect] = [:]

        for (scale, suffix) in [(SymbolScale.small, "S"),
                                (.medium, "M"),
                                (.large, "L")] {
            guard let baseline = guideY(in: guides, id: "Baseline-\(suffix)"),
                  let capline = guideY(in: guides, id: "Capline-\(suffix)") else {
                continue
            }
            let left = marginX(in: guides, edge: "left") ?? 0
            let right = marginX(in: guides, edge: "right") ?? left
            rects[scale] = TemplateRect(x: left,
                                        y: min(baseline, capline),
                                        width: max(0, right - left),
                                        height: abs(baseline - capline))
        }
        return rects
    }
}
