//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

public struct ConstraintID: Codable, Hashable, Sendable {

    public var rawValue: UUID

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

/// A declared geometric relationship.
///
/// Constraints are *invariants*, not goals. They restrict the degrees of
/// freedom available to an edit rather than being checked afterwards, so
/// geometry can never drift out of compliance and there is no violated state.
/// See spec 11.2.
public enum Constraint: Codable, Hashable, Sendable, Identifiable {

    case onGrid(OnGridConstraint)
    case onKeyShape(OnKeyShapeConstraint)
    case centered(CenteredConstraint)
    case equalSpacing(EqualSpacingConstraint)
    case equalRadius(EqualRadiusConstraint)
    case equalLength(EqualLengthConstraint)
    case tangent(TangentConstraint)
    case concentric(ConcentricConstraint)
    case symmetric(SymmetricConstraint)
    case parallel(ParallelConstraint)
    case perpendicular(PerpendicularConstraint)
    case fixedAngle(FixedAngleConstraint)
    case fixedDistance(FixedDistanceConstraint)
    case opticalOffset(OpticalOffsetConstraint)

    public var id: ConstraintID {
        body.id
    }

    /// Whether the constraint currently participates in editing.
    ///
    /// A disabled constraint keeps its record but imposes no restriction, which
    /// is how a user escapes an invariant without discarding the relationship.
    public var isEnabled: Bool {
        body.isEnabled
    }

    /// The primitives this constraint governs.
    public var affectedPrimitiveIDs: [PrimitiveID] {
        body.affectedPrimitiveIDs
    }

    /// A short description for the inspector. See spec 11.3.
    public var displayName: String {
        switch self {
        case .onGrid: "On grid intersection"
        case .onKeyShape: "On key-shape boundary"
        case .centered(let constraint): constraint.axis.displayName
        case .equalSpacing: "Equal spacing"
        case .equalRadius: "Equal radius"
        case .equalLength: "Equal length"
        case .tangent: "Tangent"
        case .concentric: "Concentric"
        case .symmetric: "Symmetric"
        case .parallel: "Parallel"
        case .perpendicular: "Perpendicular"
        case .fixedAngle: "Fixed angle"
        case .fixedDistance: "Fixed distance"
        case .opticalOffset: "Optical offset"
        }
    }

    /// The constraint with its enablement changed.
    ///
    /// A disabled constraint keeps its record and its place in the document but
    /// imposes nothing, which is how a user steps outside an invariant without
    /// losing the relationship.
    public func settingEnabled(_ enabled: Bool) -> Constraint {
        switch self {
        case .onGrid(var body): body.isEnabled = enabled; return .onGrid(body)
        case .onKeyShape(var body): body.isEnabled = enabled; return .onKeyShape(body)
        case .centered(var body): body.isEnabled = enabled; return .centered(body)
        case .equalSpacing(var body): body.isEnabled = enabled; return .equalSpacing(body)
        case .equalRadius(var body): body.isEnabled = enabled; return .equalRadius(body)
        case .equalLength(var body): body.isEnabled = enabled; return .equalLength(body)
        case .tangent(var body): body.isEnabled = enabled; return .tangent(body)
        case .concentric(var body): body.isEnabled = enabled; return .concentric(body)
        case .symmetric(var body): body.isEnabled = enabled; return .symmetric(body)
        case .parallel(var body): body.isEnabled = enabled; return .parallel(body)
        case .perpendicular(var body): body.isEnabled = enabled; return .perpendicular(body)
        case .fixedAngle(var body): body.isEnabled = enabled; return .fixedAngle(body)
        case .fixedDistance(var body): body.isEnabled = enabled; return .fixedDistance(body)
        case .opticalOffset(var body): body.isEnabled = enabled; return .opticalOffset(body)
        }
    }

    private var body: any ConstraintBody {
        switch self {
        case .onGrid(let constraint): constraint
        case .onKeyShape(let constraint): constraint
        case .centered(let constraint): constraint
        case .equalSpacing(let constraint): constraint
        case .equalRadius(let constraint): constraint
        case .equalLength(let constraint): constraint
        case .tangent(let constraint): constraint
        case .concentric(let constraint): constraint
        case .symmetric(let constraint): constraint
        case .parallel(let constraint): constraint
        case .perpendicular(let constraint): constraint
        case .fixedAngle(let constraint): constraint
        case .fixedDistance(let constraint): constraint
        case .opticalOffset(let constraint): constraint
        }
    }
}

/// The fields every constraint carries.
public protocol ConstraintBody: Codable, Hashable, Sendable {
    var id: ConstraintID { get }
    var isEnabled: Bool { get }
    var affectedPrimitiveIDs: [PrimitiveID] { get }
}
