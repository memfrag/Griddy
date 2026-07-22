//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

/// The freedom a primitive retains under its constraints.
///
/// This is how constraints are enforced: rather than letting an edit happen and
/// checking afterwards, the restriction is applied to the *input* of the edit,
/// so geometry can never drift out of compliance and there is no violated state
/// to report. See spec 11.2.
public enum DragRestriction: Equatable, Sendable {

    /// Free to move in any direction.
    case free

    /// Free to move only along a line. The vector is a unit direction.
    case axis(IconVector)

    /// Cannot move at all.
    case fixed

    /// The restriction that satisfies both.
    ///
    /// Restrictions compose by intersection: two different axes leave only
    /// their common point, which is no movement at all.
    public func intersected(with other: DragRestriction) -> DragRestriction {
        switch (self, other) {
        case (.free, _):
            return other
        case (_, .free):
            return self
        case (.fixed, _), (_, .fixed):
            return .fixed
        case (.axis(let first), .axis(let second)):
            // Parallel axes are the same freedom, whichever way they point.
            let alignment = abs(first.dot(second))
            return alignment > 1 - 1e-9 ? .axis(first) : .fixed
        }
    }

    /// A movement reduced to what this restriction permits.
    public func apply(to vector: IconVector) -> IconVector {
        switch self {
        case .free:
            return vector
        case .fixed:
            return .zero
        case .axis(let direction):
            // Project the movement onto the permitted direction.
            return direction.scaled(by: vector.dot(direction))
        }
    }

    /// The directions this restriction pins, as unit vectors.
    ///
    /// Used for conflict detection: two constraints conflict when they pin the
    /// same direction, because the second cannot change anything the first has
    /// already determined. See spec 11.2.
    public var pinnedDirections: [IconVector] {
        switch self {
        case .free:
            []
        case .fixed:
            [IconVector(dx: 1, dy: 0), IconVector(dx: 0, dy: 1)]
        case .axis(let direction):
            // Free along the axis means pinned across it.
            [direction.perpendicular]
        }
    }

    /// Whether this restriction and another pin any direction in common.
    public func pinsSameDirection(as other: DragRestriction) -> Bool {
        for first in pinnedDirections {
            for second in other.pinnedDirections
            where abs(first.dot(second)) > 1 - 1e-9 {
                return true
            }
        }
        return false
    }
}
