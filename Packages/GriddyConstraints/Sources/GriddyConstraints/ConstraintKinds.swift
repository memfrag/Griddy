//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

public enum CenteringAxis: String, Codable, Sendable {
    case horizontal
    case vertical
    case both

    public var displayName: String {
        switch self {
        case .horizontal: "Centered horizontally"
        case .vertical: "Centered vertically"
        case .both: "Centered"
        }
    }
}

/// Pins a primitive's anchor to the nearest grid intersection.
public struct OnGridConstraint: ConstraintBody {
    public var id = ConstraintID()
    public var isEnabled = true
    public var primitiveID: PrimitiveID
    public var affectedPrimitiveIDs: [PrimitiveID] { [primitiveID] }

    public init(primitiveID: PrimitiveID) {
        self.primitiveID = primitiveID
    }
}

/// Holds a primitive against a key shape's boundary, optionally overshooting
/// it by a controlled amount. See spec 6.4.
public struct OnKeyShapeConstraint: ConstraintBody {
    public var id = ConstraintID()
    public var isEnabled = true
    public var primitiveID: PrimitiveID
    public var keyShapeID: UUID
    public var overshoot: Double
    public var affectedPrimitiveIDs: [PrimitiveID] { [primitiveID] }

    public init(primitiveID: PrimitiveID, keyShapeID: UUID, overshoot: Double = 0) {
        self.primitiveID = primitiveID
        self.keyShapeID = keyShapeID
        self.overshoot = overshoot
    }
}

public struct CenteredConstraint: ConstraintBody {
    public var id = ConstraintID()
    public var isEnabled = true
    public var primitiveID: PrimitiveID
    public var axis: CenteringAxis
    public var affectedPrimitiveIDs: [PrimitiveID] { [primitiveID] }

    public init(primitiveID: PrimitiveID, axis: CenteringAxis) {
        self.primitiveID = primitiveID
        self.axis = axis
    }
}

public struct EqualSpacingConstraint: ConstraintBody {
    public var id = ConstraintID()
    public var isEnabled = true
    public var primitiveIDs: [PrimitiveID]
    public var axis: CenteringAxis
    public var affectedPrimitiveIDs: [PrimitiveID] { primitiveIDs }

    public init(primitiveIDs: [PrimitiveID], axis: CenteringAxis) {
        self.primitiveIDs = primitiveIDs
        self.axis = axis
    }
}

public struct EqualRadiusConstraint: ConstraintBody {
    public var id = ConstraintID()
    public var isEnabled = true
    public var primitiveIDs: [PrimitiveID]
    public var affectedPrimitiveIDs: [PrimitiveID] { primitiveIDs }

    public init(primitiveIDs: [PrimitiveID]) {
        self.primitiveIDs = primitiveIDs
    }
}

public struct EqualLengthConstraint: ConstraintBody {
    public var id = ConstraintID()
    public var isEnabled = true
    public var primitiveIDs: [PrimitiveID]
    public var affectedPrimitiveIDs: [PrimitiveID] { primitiveIDs }

    public init(primitiveIDs: [PrimitiveID]) {
        self.primitiveIDs = primitiveIDs
    }
}

public struct TangentConstraint: ConstraintBody {
    public var id = ConstraintID()
    public var isEnabled = true
    public var primitiveID: PrimitiveID
    public var targetPrimitiveID: PrimitiveID
    public var affectedPrimitiveIDs: [PrimitiveID] { [primitiveID, targetPrimitiveID] }

    public init(primitiveID: PrimitiveID, targetPrimitiveID: PrimitiveID) {
        self.primitiveID = primitiveID
        self.targetPrimitiveID = targetPrimitiveID
    }
}

public struct ConcentricConstraint: ConstraintBody {
    public var id = ConstraintID()
    public var isEnabled = true
    public var primitiveIDs: [PrimitiveID]
    public var affectedPrimitiveIDs: [PrimitiveID] { primitiveIDs }

    public init(primitiveIDs: [PrimitiveID]) {
        self.primitiveIDs = primitiveIDs
    }
}

public struct SymmetricConstraint: ConstraintBody {
    public var id = ConstraintID()
    public var isEnabled = true
    public var primitiveIDs: [PrimitiveID]
    public var axis: SymmetryAxis
    public var axisPosition: Double
    public var affectedPrimitiveIDs: [PrimitiveID] { primitiveIDs }

    public init(primitiveIDs: [PrimitiveID], axis: SymmetryAxis, axisPosition: Double) {
        self.primitiveIDs = primitiveIDs
        self.axis = axis
        self.axisPosition = axisPosition
    }
}

public struct ParallelConstraint: ConstraintBody {
    public var id = ConstraintID()
    public var isEnabled = true
    public var primitiveIDs: [PrimitiveID]
    public var affectedPrimitiveIDs: [PrimitiveID] { primitiveIDs }

    public init(primitiveIDs: [PrimitiveID]) {
        self.primitiveIDs = primitiveIDs
    }
}

public struct PerpendicularConstraint: ConstraintBody {
    public var id = ConstraintID()
    public var isEnabled = true
    public var primitiveIDs: [PrimitiveID]
    public var affectedPrimitiveIDs: [PrimitiveID] { primitiveIDs }

    public init(primitiveIDs: [PrimitiveID]) {
        self.primitiveIDs = primitiveIDs
    }
}

public struct FixedAngleConstraint: ConstraintBody {
    public var id = ConstraintID()
    public var isEnabled = true
    public var primitiveID: PrimitiveID
    public var angle: IconAngle
    public var affectedPrimitiveIDs: [PrimitiveID] { [primitiveID] }

    public init(primitiveID: PrimitiveID, angle: IconAngle) {
        self.primitiveID = primitiveID
        self.angle = angle
    }
}

public struct FixedDistanceConstraint: ConstraintBody {
    public var id = ConstraintID()
    public var isEnabled = true
    public var primitiveID: PrimitiveID
    public var targetPrimitiveID: PrimitiveID
    public var distance: Double
    public var affectedPrimitiveIDs: [PrimitiveID] { [primitiveID, targetPrimitiveID] }

    public init(primitiveID: PrimitiveID, targetPrimitiveID: PrimitiveID, distance: Double) {
        self.primitiveID = primitiveID
        self.targetPrimitiveID = targetPrimitiveID
        self.distance = distance
    }
}

/// A deliberate deviation from mathematical alignment, recorded as an explicit
/// property rather than an accidental path edit. See spec 6.4.
public struct OpticalOffsetConstraint: ConstraintBody {
    public var id = ConstraintID()
    public var isEnabled = true
    public var primitiveID: PrimitiveID
    public var offset: IconVector
    public var affectedPrimitiveIDs: [PrimitiveID] { [primitiveID] }

    public init(primitiveID: PrimitiveID, offset: IconVector) {
        self.primitiveID = primitiveID
        self.offset = offset
    }
}
