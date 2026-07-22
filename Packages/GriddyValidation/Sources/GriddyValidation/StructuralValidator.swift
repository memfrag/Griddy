//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry
import GriddyDocument
import GriddyConstraints

/// Tier 1: checks that read the document's structure without solving anything.
///
/// Runs synchronously on every edit, so nothing here may outline, resolve
/// booleans, or reconcile — those belong to ``GeometricValidator``. The budget
/// is under a millisecond on a document of ordinary size. See spec 15.3.
public enum StructuralValidator {

    public static func issues(in document: SymbolDocument) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        issues.append(contentsOf: degenerateGeometry(in: document))
        issues.append(contentsOf: brokenReferences(in: document))
        issues.append(contentsOf: unenforcedConstraints(in: document))
        issues.append(contentsOf: placement(in: document))

        return issues
    }

    // MARK: Checks

    /// Primitives with no extent.
    ///
    /// These outline to nothing, so they contribute no geometry and are almost
    /// always an accident — a click that registered as a drag of zero length.
    static func degenerateGeometry(in document: SymbolDocument) -> [ValidationIssue] {
        document.primitivesInDrawOrder.compactMap { primitive in
            guard let reason = degeneracy(of: primitive) else {
                return nil
            }
            return ValidationIssue(
                severity: .warning,
                category: .geometry,
                message: "\(primitive.kindName) \(reason).",
                affectedPrimitiveIDs: [primitive.id],
                suggestedFix: "Give it a size, or delete it.")
        }
    }

    private static func degeneracy(of primitive: IconPrimitive) -> String? {
        let tolerance = 1e-9

        switch primitive {
        case .circle(let circle):
            return circle.radius <= tolerance ? "has no radius" : nil
        case .line(let line):
            let dx = line.end.x - line.start.x
            let dy = line.end.y - line.start.y
            return (dx * dx + dy * dy).squareRoot() <= tolerance
                ? "has no length" : nil
        case .roundedRect(let rect):
            if rect.bounds.size.width <= tolerance
                || rect.bounds.size.height <= tolerance {
                return "has no area"
            }
            return nil
        case .capsule(let capsule):
            if capsule.bounds.size.width <= tolerance
                || capsule.bounds.size.height <= tolerance {
                return "has no area"
            }
            return nil
        case .arc(let arc):
            if arc.radius <= tolerance { return "has no radius" }
            return abs(arc.endAngle.radians - arc.startAngle.radians) <= tolerance
                ? "has no sweep" : nil
        case .polyline(let polyline):
            return polyline.points.count < 2 ? "has too few points" : nil
        case .symmetricPath(let path):
            return path.points.isEmpty ? "has no points" : nil

        // A compound's emptiness is a property of its operands, which the
        // geometric tier resolves; an imported path is whatever the SVG said.
        case .compound, .importedPath:
            return nil
        }
    }

    /// Primitives pointing at things that are not there.
    static func brokenReferences(in document: SymbolDocument) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        let orphaned = document.orphanedPrimitiveIDs
        if !orphaned.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                category: .construction,
                message: orphaned.count == 1
                    ? "A primitive belongs to no layer."
                    : "\(orphaned.count) primitives belong to no layer.",
                affectedPrimitiveIDs: orphaned,
                suggestedFix: "Assign them to a layer, or delete them."))
        }

        let dangling = document.danglingPrimitiveIDs
        if !dangling.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                category: .construction,
                message: dangling.count == 1
                    ? "A layer references a primitive that no longer exists."
                    : "\(dangling.count) layer references point at missing "
                        + "primitives.",
                affectedPrimitiveIDs: dangling,
                suggestedFix: "Removing and re-adding the layer clears these."))
        }

        return issues
    }

    /// Constraints the document stores but the solver does not act on.
    ///
    /// The inspector will happily add all of these, and four of them then do
    /// nothing at all — geometry does not move, and no error is raised. Saying
    /// so is the minimum; the alternative is a document that quietly means less
    /// than it claims. See spec 11.2.
    static func unenforcedConstraints(in document: SymbolDocument) -> [ValidationIssue] {
        let unenforced = document.constraints.filter { !$0.isEnforced }
        guard !unenforced.isEmpty else {
            return []
        }

        let names = Set(unenforced.map(\.displayName)).sorted()
            .joined(separator: ", ")

        return [ValidationIssue(
            severity: .warning,
            category: .constraint,
            message: unenforced.count == 1
                ? "The \(names) constraint is recorded but not enforced."
                : "\(unenforced.count) constraints are recorded but not "
                    + "enforced: \(names).",
            suggestedFix: "They are saved and exported, but do not move "
                + "geometry. Position the primitives by hand for now.")]
    }

    /// Artwork placed where it will not be seen.
    static func placement(in document: SymbolDocument) -> [ValidationIssue] {
        let designArea = document.coordinateSystem.designArea

        let strays = document.primitivesInDrawOrder.filter { primitive in
            guard let bounds = PrimitiveGeometry.bounds(of: primitive) else {
                return false
            }
            return !designArea.intersects(bounds)
        }

        guard !strays.isEmpty else {
            return []
        }

        return [ValidationIssue(
            severity: .warning,
            category: .geometry,
            message: strays.count == 1
                ? "A primitive sits entirely outside the design area."
                : "\(strays.count) primitives sit entirely outside the design "
                    + "area.",
            affectedPrimitiveIDs: strays.map(\.id),
            suggestedFix: "They will still export. Move them onto the canvas "
                + "or delete them.")]
    }
}
