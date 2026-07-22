//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// Makes masters interpolatable.
///
/// The SF Symbols app requires the variants in a template to interpolate, and
/// enforces it as a hard gate: a file whose masters disagree structurally is
/// refused outright with "The provided variants are not interpolatable", not
/// accepted and degraded. See spec 12.6.
///
/// Masters disagree because boolean resolution cuts outlines wherever they
/// intersect, and those intersections move as stroke width changes. A circle
/// crossed by a line yields the same two regions at every weight but a
/// different number of path pieces. This pass reconciles that without altering
/// any shape: every operation either splits a segment, which leaves the curve
/// exactly where it was, or rotates a contour's starting point.
public enum OutlineCompatibility {

    /// Why masters could not be reconciled.
    public enum Failure: Error, Equatable, LocalizedError {

        case contourCountMismatch(counts: [Int])
        case windingMismatch(index: Int)
        case emptyMaster(index: Int)
        case unreconciled(detail: String)

        public var errorDescription: String? {
            switch self {
            case .contourCountMismatch(let counts):
                "The masters enclose different numbers of regions "
                    + "(\(counts.map(String.init).joined(separator: ", "))). "
                    + "A detail probably closes up at a heavier weight."
            case .windingMismatch(let index):
                "Region \(index + 1) is a hole in one master and solid in "
                    + "another."
            case .emptyMaster(let index):
                "Master \(index + 1) has no geometry."
            case .unreconciled(let detail):
                "The masters could not be reconciled: \(detail)"
            }
        }

        public var recoverySuggestion: String? {
            switch self {
            case .contourCountMismatch, .windingMismatch:
                "Thicken the affected detail, reduce the stroke expansion for "
                    + "the heavier masters, or add a per-master adjustment."
            default:
                nil
            }
        }
    }

    /// Positions closer than this fraction of a contour's length are treated as
    /// the same place.
    ///
    /// Without it, two masters whose corners fall at 0.2499 and 0.2501 would
    /// each gain a boundary at both, leaving a hairline segment between them in
    /// every master.
    static let parameterTolerance: Double = 1e-4

    // MARK: Entry point

    /// Reconciles masters to a shared path structure.
    ///
    /// Shapes are unchanged; only their description is. Throws when the masters
    /// are genuinely different rather than merely described differently, which
    /// is a design problem the designer has to resolve.
    public static func reconcile(_ paths: [OutlinePath]) throws -> [OutlinePath] {
        guard paths.count > 1 else {
            return paths
        }

        for (index, path) in paths.enumerated() where path.isEmpty {
            throw Failure.emptyMaster(index: index)
        }

        let counts = paths.map(\.contours.count)
        guard Set(counts).count == 1 else {
            throw Failure.contourCountMismatch(counts: counts)
        }

        // Group corresponding contours across masters, then reconcile each
        // group independently.
        let groups = try correspondingContours(in: paths)
        var reconciledGroups: [[OutlineContour]] = []

        for group in groups {
            reconciledGroups.append(try reconcile(group: group))
        }

        // Reassemble, keeping group order so every master lists its regions in
        // the same sequence.
        var result: [OutlinePath] = []
        for masterIndex in paths.indices {
            result.append(OutlinePath(
                contours: reconciledGroups.map { $0[masterIndex] }))
        }

        try verify(result)
        return result
    }

    // MARK: Correspondence

    /// Matches each contour of the first master to one contour in every other.
    ///
    /// Matched by winding and proximity rather than by index: boolean stitching
    /// emits contours in whatever order the walk happens to find them, so index
    /// carries no meaning across masters.
    static func correspondingContours(in paths: [OutlinePath]) throws
    -> [[OutlineContour]] {
        let reference = paths[0].contours
        var groups: [[OutlineContour]] = reference.map { [$0] }

        for (masterIndex, path) in paths.enumerated().dropFirst() {
            var available = Array(path.contours.indices)

            for (groupIndex, group) in groups.enumerated() {
                let target = group[0]

                let candidates = available.filter {
                    path.contours[$0].isCounterclockwise == target.isCounterclockwise
                }
                guard !candidates.isEmpty else {
                    throw Failure.windingMismatch(index: groupIndex)
                }

                // Closest by centre, tie-broken by similarity of enclosed area,
                // both of which move only slightly as stroke width changes.
                let best = candidates.min { first, second in
                    cost(target, path.contours[first])
                        < cost(target, path.contours[second])
                }
                guard let best else {
                    throw Failure.unreconciled(
                        detail: "no match for region \(groupIndex + 1) "
                            + "in master \(masterIndex + 1)")
                }

                groups[groupIndex].append(path.contours[best])
                available.removeAll { $0 == best }
            }
        }
        return groups
    }

    private static func cost(_ first: OutlineContour,
                             _ second: OutlineContour) -> Double {
        let distance = first.averagePoint.distance(to: second.averagePoint)
        let areaDelta = abs(first.area - second.area)
            / max(first.area, second.area, 1e-9)
        return distance + areaDelta
    }

    // MARK: Reconciling one group

    /// Gives every contour in a group the same segment structure.
    static func reconcile(group: [OutlineContour]) throws -> [OutlineContour] {
        // Start each contour at its leftmost point, so parameter zero means the
        // same place in every master before any comparison is made.
        let aligned = try group.map { try alignedToLeftmost($0) }

        // Every master's existing segment boundaries, in normalised
        // arc length, merged into one set. Splitting all of them at this set
        // gives identical structure while preserving each shape exactly.
        var boundaries: [Double] = []
        for contour in aligned {
            boundaries.append(contentsOf: normalisedBoundaries(of: contour))
        }

        let merged = mergeNearby(boundaries)
        return aligned.map { split($0, atNormalised: merged) }
    }

    /// Rotates a contour so it begins at its leftmost point.
    static func alignedToLeftmost(_ contour: OutlineContour) throws -> OutlineContour {
        let total = contour.length
        guard total > 1e-12, !contour.segments.isEmpty else {
            throw Failure.unreconciled(detail: "a region has no length")
        }

        // Locate the leftmost point as a position around the contour.
        var accumulated = 0.0
        var bestX = Double.infinity
        var bestParameter = 0.0

        for segment in contour.segments {
            let extreme = segment.leftmostExtreme
            if extreme.x < bestX {
                bestX = extreme.x
                bestParameter = (accumulated + extreme.parameter * segment.length) / total
            }
            accumulated += segment.length
        }

        // Make it a boundary, then rotate the sequence to begin there.
        let cut = split(contour, atNormalised: [bestParameter])
        guard let startIndex = indexOfBoundary(in: cut, atNormalised: bestParameter) else {
            return cut
        }
        return rotated(cut, toStartAt: startIndex)
    }

    static func rotated(_ contour: OutlineContour, toStartAt index: Int) -> OutlineContour {
        guard index > 0, index < contour.segments.count else {
            return contour
        }
        return OutlineContour(segments: Array(contour.segments[index...])
                              + Array(contour.segments[..<index]))
    }

    /// The index of the segment whose start sits at a normalised position.
    static func indexOfBoundary(in contour: OutlineContour,
                                atNormalised parameter: Double) -> Int? {
        let total = contour.length
        guard total > 1e-12 else {
            return nil
        }

        var accumulated = 0.0
        var best: (index: Int, delta: Double)?

        for (index, segment) in contour.segments.enumerated() {
            let position = accumulated / total
            let delta = abs(position - parameter)
            if best == nil || delta < best!.delta {
                best = (index, delta)
            }
            accumulated += segment.length
        }
        return best?.index
    }

    /// Where this contour's existing segments begin, in normalised arc length.
    static func normalisedBoundaries(of contour: OutlineContour) -> [Double] {
        let total = contour.length
        guard total > 1e-12 else {
            return []
        }

        var result: [Double] = []
        var accumulated = 0.0
        for segment in contour.segments {
            result.append(accumulated / total)
            accumulated += segment.length
        }
        return result
    }

    /// Collapses positions that are the same place to within tolerance.
    static func mergeNearby(_ parameters: [Double]) -> [Double] {
        let sorted = parameters
            .filter { $0 > parameterTolerance && $0 < 1 - parameterTolerance }
            .sorted()

        var merged: [Double] = []
        for value in sorted {
            if let last = merged.last, value - last <= parameterTolerance {
                continue
            }
            merged.append(value)
        }
        return merged
    }

    /// Splits a contour at normalised positions around its length.
    ///
    /// Splitting never moves a curve: a line becomes two collinear lines and an
    /// arc two arcs on the same circle. Only the description changes.
    static func split(_ contour: OutlineContour,
                      atNormalised parameters: [Double]) -> OutlineContour {
        let total = contour.length
        guard total > 1e-12, !parameters.isEmpty else {
            return contour
        }

        var result: [OutlineSegment] = []
        var accumulated = 0.0

        for segment in contour.segments {
            let length = segment.length
            guard length > 1e-12 else {
                result.append(segment)
                continue
            }

            let start = accumulated / total
            let end = (accumulated + length) / total

            // Positions strictly inside this segment, converted to its own
            // parameter space.
            let locals = parameters
                .filter { $0 > start + parameterTolerance
                       && $0 < end - parameterTolerance }
                .map { ($0 * total - accumulated) / length }

            result.append(contentsOf: locals.isEmpty
                          ? [segment]
                          : segment.split(at: locals))
            accumulated += length
        }
        return OutlineContour(segments: result)
    }

    // MARK: Verification

    /// Confirms the result is what the SF Symbols app requires.
    ///
    /// Cheap, and it turns a subtle interpolation fault into an immediate,
    /// local failure rather than a file Apple rejects much later.
    static func verify(_ paths: [OutlinePath]) throws {
        guard let first = paths.first else {
            return
        }

        for path in paths.dropFirst() {
            guard path.contours.count == first.contours.count else {
                throw Failure.unreconciled(detail: "region counts still differ")
            }
            for (index, contour) in path.contours.enumerated() {
                guard contour.segments.count
                        == first.contours[index].segments.count else {
                    throw Failure.unreconciled(
                        detail: "region \(index + 1) still has "
                            + "\(contour.segments.count) segments against "
                            + "\(first.contours[index].segments.count)")
                }
            }
        }
    }
}
