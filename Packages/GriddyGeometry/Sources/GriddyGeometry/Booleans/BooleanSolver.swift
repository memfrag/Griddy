//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// Combines outlines into minimal, non-overlapping results.
///
/// The pipeline is the classical one for planar regions: find every crossing,
/// cut both operands at those crossings, decide for each resulting piece
/// whether it lies inside or outside the other operand, keep the pieces the
/// operation calls for, and stitch them back into closed contours.
///
/// Because outlines contain only lines and circular arcs, every crossing is
/// solved in closed form. See spec 10.5.
///
/// - Note: Degenerate configurations are not handled exactly. Coincident edges
///   (two operands sharing a stretch of boundary rather than crossing it) and
///   exact tangencies are the known cases; the solver treats a tangency as a
///   single crossing and may keep or drop a zero-area sliver. Griddy's own
///   outlines rarely produce these, because the operands come from distinct
///   primitives, but imported geometry could.
public enum BooleanSolver {

    /// Distance below which two points are treated as the same.
    ///
    /// Loose enough to absorb the rounding of an intersection computed from two
    /// different segments, tight enough not to merge genuinely distinct
    /// vertices at the scale Griddy works in (a 16-unit canvas).
    static let weldTolerance = 1e-7

    public static func combine(_ first: OutlinePath,
                               _ second: OutlinePath,
                               operation: CompoundOperation) -> OutlinePath {
        // Shortcuts that also keep the empty cases well defined.
        if first.isEmpty || second.isEmpty {
            switch operation {
            case .union: return first.isEmpty ? second : first
            case .subtract: return first
            case .intersect: return .empty
            }
        }

        let firstPieces = split(first, against: second)
        let secondPieces = split(second, against: first)

        var kept: [OutlineSegment] = []

        for piece in firstPieces {
            switch coincidence(of: piece, with: secondPieces) {
            case .sameDirection:
                // Both operands lie on the same side of this stretch of
                // boundary. It belongs to the union and to the intersection,
                // counted once; the first operand owns it and the second skips
                // it below. For a subtraction the two boundaries cancel.
                if operation != .subtract {
                    kept.append(piece)
                }

            case .oppositeDirection:
                // The operands lie on opposite sides: the boundary is interior
                // to a union and to an intersection, so it disappears. For a
                // subtraction it is exactly the cut.
                if operation == .subtract {
                    kept.append(piece)
                }

            case .none:
                let inside = isInside(piece, of: second)
                switch operation {
                case .union where !inside: kept.append(piece)
                case .intersect where inside: kept.append(piece)
                case .subtract where !inside: kept.append(piece)
                default: break
                }
            }
        }

        for piece in secondPieces {
            // Coincident stretches were already decided by the first operand.
            // Deciding them again here would duplicate the boundary.
            guard coincidence(of: piece, with: firstPieces) == .none else {
                continue
            }

            let inside = isInside(piece, of: first)
            switch operation {
            case .union where !inside:
                kept.append(piece)
            case .intersect where inside:
                kept.append(piece)
            case .subtract where inside:
                // The part of the cutter inside the target becomes the new
                // boundary of the hole, so it is traversed the other way.
                kept.append(piece.reversed)
            default:
                break
            }
        }

        return OutlinePath(contours: stitch(kept))
    }

    public static func union(_ paths: [OutlinePath]) -> OutlinePath {
        guard var result = paths.first else {
            return .empty
        }
        for path in paths.dropFirst() {
            result = combine(result, path, operation: .union)
        }
        return result
    }

    // MARK: Splitting

    /// Cuts every segment of `path` wherever it crosses `other`.
    private static func split(_ path: OutlinePath,
                              against other: OutlinePath) -> [OutlineSegment] {
        let otherSegments = other.contours.flatMap(\.segments)
        var pieces: [OutlineSegment] = []

        for contour in path.contours {
            for segment in contour.segments {
                var parameters: [Double] = []
                for candidate in otherSegments {
                    for crossing in SegmentIntersection.crossings(segment, candidate) {
                        parameters.append(crossing.t)
                    }
                }
                pieces.append(contentsOf: segment.split(at: parameters))
            }
        }
        return pieces
    }

    // MARK: Classification

    /// Whether a piece lies inside a path.
    ///
    /// Sampled at the piece's midpoint. Because the piece has already been cut
    /// at every crossing, it lies wholly inside or wholly outside, so one
    /// sample decides it. Testing an endpoint instead would land exactly on the
    /// other operand's boundary, where containment is ambiguous.
    private static func isInside(_ piece: OutlineSegment,
                                 of path: OutlinePath) -> Bool {
        PointContainment.contains(path, piece.point(at: 0.5))
    }

    // MARK: Coincident boundaries

    /// How a piece relates to an identical stretch of the other operand.
    enum Coincidence {
        case none
        case sameDirection
        case oppositeDirection
    }

    /// Whether a piece lies exactly on top of a piece of the other operand.
    ///
    /// Two shapes sharing a stretch of boundary rather than crossing it is the
    /// classic degenerate case, and a common one here: axis-aligned artwork
    /// shares edge lines constantly. Midpoint containment cannot decide such a
    /// piece, because its midpoint sits exactly on the other operand's
    /// boundary where inside and outside are both defensible. Detecting the
    /// coincidence and resolving it by direction avoids asking the question.
    static func coincidence(of piece: OutlineSegment,
                            with others: [OutlineSegment]) -> Coincidence {
        for other in others {
            guard let direction = coincidenceDirection(piece, other) else {
                continue
            }
            return direction
        }
        return .none
    }

    private static func coincidenceDirection(_ first: OutlineSegment,
                                             _ second: OutlineSegment) -> Coincidence? {
        switch (first, second) {
        case (.line(let a0, let a1), .line(let b0, let b1)):
            if matches(a0, b0), matches(a1, b1) {
                return .sameDirection
            }
            if matches(a0, b1), matches(a1, b0) {
                return .oppositeDirection
            }
            return nil

        case (.arc(let a), .arc(let b)):
            // Same underlying circle, and the same stretch of it.
            guard matches(a.center, b.center),
                  abs(a.radius - b.radius) <= weldTolerance else {
                return nil
            }
            if matches(a.startPoint, b.startPoint), matches(a.endPoint, b.endPoint) {
                return a.isClockwise == b.isClockwise ? .sameDirection : nil
            }
            if matches(a.startPoint, b.endPoint), matches(a.endPoint, b.startPoint) {
                return a.isClockwise == b.isClockwise ? nil : .oppositeDirection
            }
            return nil

        default:
            // A line and an arc can touch but never coincide over a stretch.
            return nil
        }
    }

    private static func matches(_ first: IconPoint, _ second: IconPoint) -> Bool {
        first.distance(to: second) <= weldTolerance
    }

    // MARK: Stitching

    /// Chains loose segments into closed contours.
    ///
    /// Segments are welded end to start within ``weldTolerance``. A chain that
    /// cannot be closed is discarded rather than emitted: an unclosed contour
    /// would fill as nonsense, and dropping it makes the failure visible as
    /// missing area rather than as corruption.
    static func stitch(_ segments: [OutlineSegment]) -> [OutlineContour] {
        guard !segments.isEmpty else {
            return []
        }

        var remaining = segments
        var contours: [OutlineContour] = []

        while !remaining.isEmpty {
            var chain = [remaining.removeFirst()]

            while true {
                guard let tail = chain.last?.end else {
                    break
                }
                // Closed?
                if let head = chain.first?.start,
                   chain.count > 1,
                   tail.distance(to: head) <= weldTolerance {
                    break
                }
                guard let next = remaining.firstIndex(where: {
                    $0.start.distance(to: tail) <= weldTolerance
                }) else {
                    break
                }
                chain.append(remaining.remove(at: next))
            }

            // A single segment can be a complete contour: a full circle is one
            // closed arc whose start and end coincide.
            guard let head = chain.first?.start,
                  let tail = chain.last?.end,
                  tail.distance(to: head) <= weldTolerance else {
                continue
            }

            let contour = OutlineContour(segments: chain)
            // Zero-area chains are slivers thrown up by near-tangencies and
            // carry no region.
            if contour.area > 1e-12 {
                contours.append(contour)
            }
        }

        return contours
    }
}
