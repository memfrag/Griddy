//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry
import GriddyDocument
import GriddySymbols

/// Tier 2: checks that have to solve geometry to answer.
///
/// Outlines every master, resolves booleans and reconciles — hundreds of times
/// more work than tier 1, so it runs debounced and off the main actor. See
/// spec 15.3.
///
/// The point of this tier is to answer, continuously, the question the SF
/// Symbols app answers only at import time: *will this file be accepted?*
/// Every check here corresponds to a failure that has actually happened.
public enum GeometricValidator {

    public static func issues(in document: SymbolDocument) -> [ValidationIssue] {
        var outlines: [OutlinePath] = []
        var issues: [ValidationIssue] = []

        for weight in SymbolWeight.authored {
            outlines.append(document.resolvedOutline(weight: weight))
        }

        let empty = zip(SymbolWeight.authored, outlines).filter { $1.isEmpty }
        if empty.count == SymbolWeight.authored.count {
            // Nothing drawn yet is a normal state, not a fault.
            return document.primitives.isEmpty ? [] : [ValidationIssue(
                severity: .error,
                category: .geometry,
                message: "The artwork resolves to nothing at every weight.",
                suggestedFix: "Check that primitives are on a visible layer "
                    + "and have a stroke width.")]
        }

        if !empty.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                category: .export,
                message: "The \(empty.map(\.0.rawValue).joined(separator: " and ")) "
                    + "master is empty while others are not.",
                suggestedFix: "Every authored master must carry artwork, or "
                    + "the symbol cannot interpolate."))
            return issues
        }

        // Reconciliation is the gate. If the masters cannot be brought to a
        // shared structure there is no file to write, and finding that out at
        // export time is finding out too late.
        let reconciled: [OutlinePath]
        do {
            reconciled = try OutlineCompatibility.reconcile(outlines)
        } catch {
            issues.append(ValidationIssue(
                severity: .error,
                category: .export,
                message: "The masters cannot be reconciled: "
                    + "\(reconcileFailure(error)).",
                suggestedFix: "The masters are topologically different — a "
                    + "detail that closes up at heavy weights, most often. "
                    + "Simplify until every weight has the same parts."))
            return issues
        }

        issues.append(contentsOf: interpolability(of: reconciled))
        issues.append(contentsOf: metrics(of: reconciled, in: document))
        issues.append(contentsOf: inflation(from: outlines, to: reconciled))
        return issues
    }

    // MARK: Checks

    /// Whether the masters share a command sequence.
    ///
    /// **Counts are not enough.** An export with 2 subpaths and exactly 50
    /// commands in every master was still refused: interpolation pairs command
    /// *i* with command *i*, and a line cannot interpolate with a curve however
    /// well the totals agree. See spec 12.6.
    ///
    /// Export closes that hole by converting all masters together and emitting
    /// a curve wherever *any* master curves, so matching sequences are now
    /// guaranteed — provided reconciliation delivered equal segment counts.
    /// That proviso is what this checks. When it does not hold, the converter's
    /// bounds check silently skips segments for the short master and the
    /// sequences diverge again.
    ///
    /// Comparing the emitted commands cannot serve here, and it is worth saying
    /// why. The converter takes its contour and segment counts from the *first*
    /// master and bounds-checks the rest, so a longer master is silently
    /// truncated to match and the sequences agree however badly reconciliation
    /// went. Comparing the structure it derives those counts from is the check
    /// that can actually fail.
    static func interpolability(of masters: [OutlinePath]) -> [ValidationIssue] {
        guard let reference = masters.first else {
            return []
        }

        for (index, master) in masters.enumerated().dropFirst() {
            let weight = index < SymbolWeight.authored.count
                ? SymbolWeight.authored[index].rawValue : "\(index)"
            let first = SymbolWeight.authored.first?.rawValue ?? "first"

            guard master.contours.count == reference.contours.count else {
                return [ValidationIssue(
                    severity: .error,
                    category: .export,
                    message: "The \(weight) master has "
                        + "\(master.contours.count) separate shapes where the "
                        + "\(first) master has \(reference.contours.count).",
                    suggestedFix: "Masters must have the same parts to "
                        + "interpolate. A detail that closes up at heavy "
                        + "weights is the usual cause.")]
            }

            for (contourIndex, contour) in master.contours.enumerated()
            where contour.segments.count
                != reference.contours[contourIndex].segments.count {
                return [ValidationIssue(
                    severity: .error,
                    category: .export,
                    message: "The \(weight) master's shape \(contourIndex + 1) "
                        + "has \(contour.segments.count) segments where the "
                        + "\(first) master has "
                        + "\(reference.contours[contourIndex].segments.count).",
                    suggestedFix: "Reconciliation should have equalised these. "
                        + "Exporting would silently drop the extra segments.")]
            }
        }
        return []
    }

    /// Whether every master claims the same left side bearing.
    ///
    /// A bearing that changes with weight is a symbol that slides sideways as
    /// it bolds. Measured on a real Griddy export before export normalised it:
    /// 27.20, 25.99 and 23.45 template units. See spec 9.5.
    static func metrics(of masters: [OutlinePath],
                        in document: SymbolDocument) -> [ValidationIssue] {
        let resolved = zip(SymbolWeight.authored, masters).map { weight, outline in
            ResolvedMargins.resolve(outline: outline,
                                    weight: weight,
                                    margins: document.margins,
                                    coordinateSystem: document.coordinateSystem)
        }

        let bearings = resolved.map(\.metrics.leftSideBearing)
        guard let low = bearings.min(), let high = bearings.max(),
              high - low > 1e-6 else {
            return []
        }

        return [ValidationIssue(
            severity: .warning,
            category: .visual,
            message: "The masters have different left side bearings, so the "
                + "symbol will drift sideways as the weight changes.",
            suggestedFix: "Clear the per-weight margin overrides to return "
                + "every master to the standard bearing.")]
    }

    /// How much reconciliation grew the path.
    ///
    /// Interpolability is bought with redundant on-curve points. That is worth
    /// paying, but it should not be paid silently: spec 12.6 asks for the cost
    /// to be reported.
    static func inflation(from original: [OutlinePath],
                          to reconciled: [OutlinePath]) -> [ValidationIssue] {
        let before = original.reduce(0) { $0 + $1.segmentCount }
        let after = reconciled.reduce(0) { $0 + $1.segmentCount }
        guard before > 0 else {
            return []
        }

        let ratio = Double(after) / Double(before)
        guard ratio > 2 else {
            return []
        }

        return [ValidationIssue(
            severity: .info,
            category: .export,
            message: String(format: "Reconciling the masters grows the path "
                            + "%.1f times, from %d segments to %d.",
                            ratio, before, after),
            suggestedFix: "Masters whose outlines cut at different places need "
                + "more points to correspond. Simpler overlaps reconcile more "
                + "cheaply.")]
    }

    private static func reconcileFailure(_ error: Error) -> String {
        guard let failure = error as? OutlineCompatibility.Failure else {
            return "\(error)"
        }
        switch failure {
        case .contourCountMismatch:
            return "the masters have different numbers of contours"
        case .windingMismatch:
            return "corresponding contours wind in opposite directions"
        case .emptyMaster:
            return "a master has no geometry"
        case .unreconciled:
            return "the masters could not be brought to a shared structure"
        }
    }
}
