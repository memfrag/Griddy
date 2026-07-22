//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry
import GriddyDocument

public enum TemplateExportError: Error, Equatable, LocalizedError {

    case noSourceTemplate
    case notAnAuthoringTemplate(slotCount: Int)
    case missingSlot(String)
    case degenerateTransform(String)

    public var errorDescription: String? {
        switch self {
        case .noSourceTemplate:
            "This document has no source template to export into."
        case .notAnAuthoringTemplate(let count):
            "This document was imported from a fully populated template with "
                + "\(count) artwork slots. Griddy authors three masters, so "
                + "exporting into it would leave the other slots showing the "
                + "original symbol."
        case .missingSlot(let name):
            "The template has no \(name) slot to write into."
        case .degenerateTransform(let name):
            "The \(name) slot's transform cannot be inverted."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .notAnAuthoringTemplate:
            "Start from a blank template, or import an authoring template "
                + "exported from the SF Symbols app."
        default:
            nil
        }
    }
}

/// What an export produced, beyond the file itself.
public struct ExportReport: Equatable, Sendable {

    /// Which subpath ranges belong to which layer, and what each was meant to
    /// be.
    ///
    /// Layer semantics cannot be carried in the SVG; they are assigned in the
    /// SF Symbols app after import and lost on every re-import. Griddy knows
    /// the intent and controls the ordering, so it hands the intent back as
    /// instructions. See spec 14.6.
    public struct LayerAssignment: Equatable, Sendable {
        public var layerName: String
        public var role: SymbolLayerRole
        public var firstSubpath: Int
        public var subpathCount: Int

        public var range: String {
            subpathCount == 1
                ? "subpath \(firstSubpath)"
                : "subpath \(firstSubpath)-\(firstSubpath + subpathCount - 1)"
        }
    }

    public var slotsWritten: [SymbolSlot]
    public var subpathCounts: [SymbolSlot: Int]

    /// Path commands per master.
    ///
    /// Tracked separately from subpath counts because they disagree in
    /// practice: a circle and a line unioned at three weights produced two
    /// subpaths at every weight but 19, 17 and 17 commands, since boolean
    /// resolution yields a different number of pieces as the stroke changes.
    /// Comparing subpaths alone would call that compatible.
    public var commandCounts: [SymbolSlot: Int]

    /// Outline segments before and after reconciliation.
    ///
    /// Reconciliation buys interpolability by inserting redundant on-curve
    /// points, so the exported path is larger than the minimal outline the
    /// solver produced. Spec 12.6 asks for that cost to be reported rather
    /// than absorbed silently.
    public var segmentsBeforeReconciliation: Int
    public var segmentsAfterReconciliation: Int

    public var layerAssignments: [LayerAssignment]
    public var warnings: [String]

    /// How much larger reconciliation made the path, as a multiple.
    public var nodeInflation: Double {
        guard segmentsBeforeReconciliation > 0 else {
            return 1
        }
        return Double(segmentsAfterReconciliation)
            / Double(segmentsBeforeReconciliation)
    }

    /// Whether the masters share a path structure.
    ///
    /// A cheap stand-in for the full compatibility pass: matching counts do not
    /// guarantee the masters reconcile, but differing counts guarantee they do
    /// not. Apple's own templates hold both counts identical across every slot.
    /// See spec 12.6 and 15.1.
    public var mastersShareStructure: Bool {
        Set(subpathCounts.values).count <= 1 && Set(commandCounts.values).count <= 1
    }
}

/// Writes SF Symbols templates.
///
/// Export substitutes path data into the original template text rather than
/// re-serialising a parsed tree. That makes "preserve the template" literally
/// true: the difference between input and output is exactly the artwork, and
/// anything Griddy does not model survives byte for byte. See spec 14.4.
public enum SFSymbolTemplateExporter {

    public static func export(
        document: SymbolDocument,
        sourceTemplate: Data?
    ) throws -> (data: Data, report: ExportReport) {
        guard let sourceTemplate,
              var text = String(data: sourceTemplate, encoding: .utf8) else {
            throw TemplateExportError.noSourceTemplate
        }

        let template = try SFSymbolTemplateImporter.import(sourceTemplate)

        // The authoring template is the export target. Writing three masters
        // into a 27-slot static export would leave 24 slots showing the symbol
        // it was exported from, which is worse than refusing.
        guard template.variants.count <= SymbolWeight.authored.count else {
            throw TemplateExportError.notAnAuthoringTemplate(
                slotCount: template.variants.count)
        }

        let scale = SFSymbolTemplateImporter.canonicalScale(for: template.variants)
        let slotTransforms = try slotTransforms(in: sourceTemplate)

        var subpathCounts: [SymbolSlot: Int] = [:]
        var commandCounts: [SymbolSlot: Int] = [:]
        var written: [SymbolSlot] = []
        var warnings: [String] = []

        // Resolve every master before writing any of them: reconciliation
        // needs all three at once, which is the one genuine barrier in the
        // pipeline. See spec 14.5.
        var outlines: [OutlinePath] = []
        for weight in SymbolWeight.authored {
            let outline = document.resolvedOutline(weight: weight)
            if outline.isEmpty {
                warnings.append("The \(weight.rawValue) master is empty.")
            }
            outlines.append(outline)
        }

        // Reconcile them to a shared path structure. Without this the SF
        // Symbols app refuses the file outright: "The provided variants are
        // not interpolatable". See spec 12.6.
        let reconciled = try OutlineCompatibility.reconcile(outlines)

        let segmentsBefore = outlines.reduce(0) { $0 + $1.segmentCount }
        let segmentsAfter = reconciled.reduce(0) { $0 + $1.segmentCount }

        // Every slot group carries the same transform in these templates, so
        // one mapping serves all three. Converting the masters together is what
        // keeps their command counts equal after arcs expand into cubics.
        guard let referenceSlot = template.variants[
            SymbolSlot(weight: .regular, scale: scale)],
              let referenceTransform = slotTransforms[referenceSlot.elementID],
              let referenceInverse = referenceTransform.inverted else {
            throw TemplateExportError.missingSlot("Regular-\(scaleSuffix(scale))")
        }

        let commandsPerMaster = reconciled.svgCommandsForReconciledMasters { point in
            referenceInverse.apply(
                to: document.coordinateSystem.templatePoint(from: point))
        }

        text = substitute(symbolName: document.metadata.name, in: text)

        for (index, weight) in SymbolWeight.authored.enumerated() {
            let slot = SymbolSlot(weight: weight, scale: scale)
            guard let variant = template.variants[slot] else {
                throw TemplateExportError.missingSlot(
                    "\(weight.rawValue.capitalized)-\(scaleSuffix(scale))")
            }
            guard slotTransforms[variant.elementID]?.inverted != nil else {
                throw TemplateExportError.degenerateTransform(variant.elementID)
            }

            let commands = commandsPerMaster[index]

            text = try substitute(pathData: SVGPathWriter.write(commands),
                                  inSlot: variant.elementID,
                                  of: text)

            subpathCounts[slot] = commands.reduce(0) { total, command in
                if case .move = command { return total + 1 }
                return total
            }
            commandCounts[slot] = commands.count
            written.append(slot)
        }

        // Both counts must agree. Subpaths alone is not enough: boolean
        // resolution can produce the same number of regions from a different
        // number of pieces as the stroke width changes.
        if Set(subpathCounts.values).count > 1 {
            let counts = subpathCounts.values.sorted()
                .map(String.init).joined(separator: ", ")
            warnings.append(
                "The masters have different subpath counts (\(counts)) and will "
                + "not interpolate until reconciled.")
        } else if Set(commandCounts.values).count > 1 {
            let counts = commandCounts.values.sorted()
                .map(String.init).joined(separator: ", ")
            warnings.append(
                "The masters have matching subpaths but different path command "
                + "counts (\(counts)). They will not interpolate until "
                + "reconciled; see the outline compatibility pass.")
        }

        return (
            Data(text.utf8),
            ExportReport(slotsWritten: written,
                         subpathCounts: subpathCounts,
                         commandCounts: commandCounts,
                         segmentsBeforeReconciliation: segmentsBefore,
                         segmentsAfterReconciliation: segmentsAfter,
                         layerAssignments: layerAssignments(for: document,
                                                            weight: .regular),
                         warnings: warnings)
        )
    }

    // MARK: Layer assignments

    /// The reassignment checklist, per spec 14.6.
    static func layerAssignments(for document: SymbolDocument,
                                 weight: SymbolWeight) -> [ExportReport.LayerAssignment] {
        var assignments: [ExportReport.LayerAssignment] = []
        var nextSubpath = 1

        for layer in document.layers where layer.isVisible {
            let primitives = document.primitives(in: layer).filter {
                $0.attributes.isVisible && $0.attributes.participatesInExport
            }
            guard !primitives.isEmpty else {
                continue
            }

            let count = primitives.reduce(0) { total, primitive in
                let outline = document.outline(for: primitive, weight: weight)
                return total + (outline?.contours.count ?? 0)
            }
            guard count > 0 else {
                continue
            }

            assignments.append(ExportReport.LayerAssignment(
                layerName: layer.name,
                role: layer.role,
                firstSubpath: nextSubpath,
                subpathCount: count
            ))
            nextSubpath += count
        }
        return assignments
    }

    // MARK: Text substitution

    /// Every slot group's accumulated transform, keyed by element identifier.
    static func slotTransforms(in data: Data) throws -> [String: SVGTransform] {
        let root = try SVGParser.parse(data)
        var found: [String: SVGTransform] = [:]

        root.walk { element, transform in
            guard let id = element.id,
                  SFSymbolTemplateImporter.slot(fromElementID: id) != nil else {
                return
            }
            found[id] = transform
        }
        return found
    }

    /// Writes the document's name wherever the template records a symbol name.
    ///
    /// Templates that came straight out of the SF Symbols app record no name at
    /// all: their root is `Notes`/`Guides`/`Symbols` with no wrapper, and the
    /// name lives in the filename. A template that has been through a vector
    /// editor gains a `<title>` and a root group named after the symbol, and
    /// ``SFSymbolTemplateImporter/symbolName(in:)`` reads them back. Griddy's own
    /// blank template is such a file, so without this the name never reaches the
    /// export and a renamed document round-trips to whatever the template
    /// happened to be called.
    ///
    /// A no-op on templates carrying no name, which is the correct behaviour for
    /// Apple's own format rather than a gap. See spec 14.5.
    static func substitute(symbolName name: String, in text: String) -> String {
        guard let existing = currentSymbolName(in: text), existing != name else {
            return text
        }
        return text
            .replacingOccurrences(of: "<title>\(existing)</title>",
                                  with: "<title>\(name)</title>")
            .replacingOccurrences(of: "<g id=\"\(existing)\"",
                                  with: "<g id=\"\(name)\"")
    }

    /// The name the template currently records, if it records one.
    private static func currentSymbolName(in text: String) -> String? {
        if let open = text.range(of: "<title>"),
           let close = text.range(of: "</title>", range: open.upperBound..<text.endIndex) {
            let title = String(text[open.upperBound..<close.lowerBound])
            if !title.isEmpty {
                return title
            }
        }

        // No title, so fall back to a root group named for the symbol. Matched
        // on the "custom." prefix rather than position: the structural groups
        // are named Notes/Guides/Symbols/Group and must never be renamed.
        guard let start = text.range(of: "<g id=\"custom."),
              let end = text.range(of: "\"", range: start.upperBound..<text.endIndex) else {
            return nil
        }
        return "custom." + text[start.upperBound..<end.lowerBound]
    }

    /// Replaces the path data inside a slot group, or inserts a path when the
    /// slot is empty, as a blank template's slots are.
    static func substitute(pathData: String,
                           inSlot id: String,
                           of text: String) throws -> String {
        guard let group = groupRange(id: id, in: text) else {
            throw TemplateExportError.missingSlot(id)
        }

        let body = text[group.body]

        // Replace the first `d` attribute inside the group if there is one.
        if let d = body.range(of: #"\sd="[^"]*""#, options: .regularExpression) {
            return text.replacingCharacters(in: d, with: " d=\"\(pathData)\"")
        }

        // Otherwise the slot is empty: insert a path element.
        return text.replacingCharacters(
            in: group.body,
            with: "<path d=\"\(pathData)\"/>"
        )
    }

    /// The extent of a group element and of its contents.
    static func groupRange(id: String, in text: String)
    -> (whole: Range<String.Index>, body: Range<String.Index>)? {
        guard let openStart = text.range(of: "<g id=\"\(id)\"") else {
            return nil
        }
        guard let openEnd = text.range(of: ">", range: openStart.upperBound..<text.endIndex)
        else {
            return nil
        }

        // Walk forward tracking nesting so the matching close tag is found
        // rather than the first one.
        var depth = 1
        var cursor = openEnd.upperBound

        while depth > 0, cursor < text.endIndex {
            let open = text.range(of: "<g", range: cursor..<text.endIndex)
            let close = text.range(of: "</g>", range: cursor..<text.endIndex)

            guard let close else {
                return nil
            }
            if let open, open.lowerBound < close.lowerBound {
                depth += 1
                cursor = open.upperBound
            } else {
                depth -= 1
                if depth == 0 {
                    return (openStart.lowerBound..<close.upperBound,
                            openEnd.upperBound..<close.lowerBound)
                }
                cursor = close.upperBound
            }
        }
        return nil
    }

    static func scaleSuffix(_ scale: SymbolScale) -> String {
        SFSymbolTemplateImporter.scaleSuffix(scale)
    }
}
