//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

/// Per-master geometry adjustments and how they propagate across the weight
/// axis. See spec 12.5.
public extension SymbolDocument {

    /// The geometry adjustment for a primitive at any weight.
    ///
    /// At an authored weight it is that master's own adjustment. At a derived
    /// weight it is interpolated between the two authored masters that bracket
    /// it — piecewise linear on the same axis the stroke expansion uses (§12.3)
    /// — so an intermediate weight moves and grows smoothly between the
    /// anchors the designer set, rather than snapping.
    ///
    /// The base primitive is the canonical shape; every master, Regular
    /// included, is a deviation from it. Interpolating the deviations and then
    /// applying them keeps the three anchors exact while filling the gaps.
    func adjustment(for primitiveID: PrimitiveID,
                    weight: SymbolWeight) -> MasterAdjustment {
        if let authored = master(for: weight)?.adjustment(for: primitiveID) {
            return authored
        }

        // A derived weight: bracket it and interpolate.
        let position = weight.axisPosition
        let (low, high, t): (SymbolWeight, SymbolWeight, Double) = position <= 1
            ? (.ultralight, .regular, position)
            : (.regular, .black, position - 1)

        return MasterAdjustment.interpolate(
            adjustment(for: primitiveID, at: low),
            adjustment(for: primitiveID, at: high),
            t: t,
            primitiveID: primitiveID)
    }

    /// An authored master's adjustment, or a zero adjustment if it has none.
    private func adjustment(for primitiveID: PrimitiveID,
                            at weight: SymbolWeight) -> MasterAdjustment {
        master(for: weight)?.adjustment(for: primitiveID)
            ?? MasterAdjustment(primitiveID: primitiveID)
    }

    /// A primitive with a weight's geometry adjustment applied.
    ///
    /// Applies position, radius and corner-radius deviations. Stroke width is
    /// resolved separately, in ``strokeWidth(for:weight:)``, because it is the
    /// input to outlining rather than a change to the primitive's shape.
    func adjusted(_ primitive: IconPrimitive,
                  weight: SymbolWeight) -> IconPrimitive {
        let adjustment = adjustment(for: primitive.id, weight: weight)
        guard !adjustment.isGeometricallyIdentity else {
            return primitive
        }

        var result = primitive

        if adjustment.positionOffset != .zero {
            result = result.translated(by: adjustment.positionOffset)
        }
        if adjustment.radiusDelta != 0, let radius = result.radius {
            result = result.settingRadius(radius + adjustment.radiusDelta)
        }
        if adjustment.cornerRadiusDelta != 0, let corner = result.cornerRadius {
            result = result.settingCornerRadius(corner + adjustment.cornerRadiusDelta)
        }
        return result
    }

    /// Replaces a primitive's adjustment for one weight, creating the master's
    /// entry if it does not exist yet.
    ///
    /// Only authored weights carry masters; a derived weight is computed and
    /// cannot be adjusted directly, so this is a no-op for one.
    mutating func setAdjustment(_ adjustment: MasterAdjustment,
                               weight: SymbolWeight) {
        guard let index = masters.firstIndex(where: {
            $0.weight == weight && $0.scale == .medium
        }) else {
            return
        }
        masters[index].setAdjustment(adjustment)
    }
}

public extension MasterAdjustment {

    /// Whether the adjustment changes a primitive's shape at all.
    ///
    /// Stroke and optical compensation are excluded: they are resolved
    /// elsewhere, so an adjustment that only sets those still counts as
    /// geometrically identity for the purpose of ``SymbolDocument/adjusted``.
    var isGeometricallyIdentity: Bool {
        positionOffset == .zero && radiusDelta == 0 && cornerRadiusDelta == 0
    }

    /// A piecewise-linear blend of two adjustments' geometry.
    ///
    /// Stroke width interpolates through ``WeightPropagationSettings`` rather
    /// than here, so it is not blended in this path; only the shape deltas are.
    static func interpolate(_ low: MasterAdjustment,
                            _ high: MasterAdjustment,
                            t: Double,
                            primitiveID: PrimitiveID) -> MasterAdjustment {
        func lerp(_ a: Double, _ b: Double) -> Double { a + (b - a) * t }
        return MasterAdjustment(
            primitiveID: primitiveID,
            positionOffset: IconVector(
                dx: lerp(low.positionOffset.dx, high.positionOffset.dx),
                dy: lerp(low.positionOffset.dy, high.positionOffset.dy)),
            radiusDelta: lerp(low.radiusDelta, high.radiusDelta),
            cornerRadiusDelta: lerp(low.cornerRadiusDelta, high.cornerRadiusDelta))
    }
}
