//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

/// A symbol variant for a specific weight and scale.
///
/// In the MVP exactly three masters are authored: Ultralight, Regular and Black,
/// all at Medium scale. The remaining 24 slots are derived at export time and
/// are not persisted. See spec 12.1 and 13.5.
public struct SymbolMaster: Codable, Hashable, Sendable, Identifiable {

    public var id: UUID
    public var weight: SymbolWeight
    public var scale: SymbolScale

    /// Per-primitive deviations, stored as an array rather than a dictionary.
    ///
    /// `MasterAdjustment` already carries its own `primitiveID`, and a
    /// dictionary keyed by a non-string type encodes as an alternating
    /// key/value array in JSON, which would make the package unreadable by
    /// hand. Use ``adjustment(for:)`` to look one up.
    public var adjustments: [MasterAdjustment]

    public var isDerived: Bool

    public init(id: UUID = UUID(),
                weight: SymbolWeight,
                scale: SymbolScale = .medium,
                adjustments: [MasterAdjustment] = [],
                isDerived: Bool = false) {
        self.id = id
        self.weight = weight
        self.scale = scale
        self.adjustments = adjustments
        self.isDerived = isDerived
    }

    public var slot: SymbolSlot {
        SymbolSlot(weight: weight, scale: scale)
    }

    public func adjustment(for primitiveID: PrimitiveID) -> MasterAdjustment? {
        adjustments.first { $0.primitiveID == primitiveID }
    }

    /// Inserts or replaces the adjustment for a primitive.
    public mutating func setAdjustment(_ adjustment: MasterAdjustment) {
        if let index = adjustments.firstIndex(where: {
            $0.primitiveID == adjustment.primitiveID
        }) {
            adjustments[index] = adjustment
        } else {
            adjustments.append(adjustment)
        }
    }

    /// The three authored masters a new document starts with. See spec 12.1.
    public static var authoredDefaults: [SymbolMaster] {
        SymbolWeight.authored.map { SymbolMaster(weight: $0) }
    }
}

/// A per-master deviation from the canonical construction.
///
/// Adjustments are keyed by primitive identity so a primitive stays the same
/// object across every master. They must never add or remove primitives. See
/// spec 10.2 and 12.5.
public struct MasterAdjustment: Codable, Hashable, Sendable {

    public var primitiveID: PrimitiveID
    public var strokeWidthDelta: Double
    public var positionOffset: IconVector
    public var radiusDelta: Double
    public var cornerRadiusDelta: Double
    public var opticalCompensation: OpticalCompensation

    public init(primitiveID: PrimitiveID,
                strokeWidthDelta: Double = 0,
                positionOffset: IconVector = .zero,
                radiusDelta: Double = 0,
                cornerRadiusDelta: Double = 0,
                opticalCompensation: OpticalCompensation = .none) {
        self.primitiveID = primitiveID
        self.strokeWidthDelta = strokeWidthDelta
        self.positionOffset = positionOffset
        self.radiusDelta = radiusDelta
        self.cornerRadiusDelta = cornerRadiusDelta
        self.opticalCompensation = opticalCompensation
    }
}

public struct OpticalCompensation: Codable, Hashable, Sendable {

    public var interiorCompensation: Double
    public var overshoot: Double

    public static let none = OpticalCompensation(interiorCompensation: 0, overshoot: 0)

    public init(interiorCompensation: Double, overshoot: Double) {
        self.interiorCompensation = interiorCompensation
        self.overshoot = overshoot
    }
}

/// How stroke width and interior compensation vary across the weight axis.
///
/// The six non-authored weights interpolate these values piecewise between the
/// authored anchors, then solve independently. See spec 12.3.
public struct WeightPropagationSettings: Codable, Hashable, Sendable {

    public var ultralightStrokeExpansion: Double
    public var regularStrokeExpansion: Double
    public var blackStrokeExpansion: Double
    public var ultralightInteriorCompensation: Double
    public var regularInteriorCompensation: Double
    public var blackInteriorCompensation: Double

    public static let `default` = WeightPropagationSettings(
        ultralightStrokeExpansion: 0.65,
        regularStrokeExpansion: 1.20,
        blackStrokeExpansion: 2.35,
        ultralightInteriorCompensation: 0.00,
        regularInteriorCompensation: 0.10,
        blackInteriorCompensation: 0.45
    )

    public init(ultralightStrokeExpansion: Double,
                regularStrokeExpansion: Double,
                blackStrokeExpansion: Double,
                ultralightInteriorCompensation: Double,
                regularInteriorCompensation: Double,
                blackInteriorCompensation: Double) {
        self.ultralightStrokeExpansion = ultralightStrokeExpansion
        self.regularStrokeExpansion = regularStrokeExpansion
        self.blackStrokeExpansion = blackStrokeExpansion
        self.ultralightInteriorCompensation = ultralightInteriorCompensation
        self.regularInteriorCompensation = regularInteriorCompensation
        self.blackInteriorCompensation = blackInteriorCompensation
    }

    /// The stroke expansion for any weight, interpolated between the three
    /// authored anchors at axis positions 0, 1 and 2.
    public func strokeExpansion(for weight: SymbolWeight) -> Double {
        interpolate(weight: weight,
                    atUltralight: ultralightStrokeExpansion,
                    atRegular: regularStrokeExpansion,
                    atBlack: blackStrokeExpansion)
    }

    public func interiorCompensation(for weight: SymbolWeight) -> Double {
        interpolate(weight: weight,
                    atUltralight: ultralightInteriorCompensation,
                    atRegular: regularInteriorCompensation,
                    atBlack: blackInteriorCompensation)
    }

    private func interpolate(weight: SymbolWeight,
                             atUltralight: Double,
                             atRegular: Double,
                             atBlack: Double) -> Double {
        let position = weight.axisPosition
        if position <= 1 {
            return atUltralight + (atRegular - atUltralight) * position
        }
        return atRegular + (atBlack - atRegular) * (position - 1)
    }
}
