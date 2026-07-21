//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// The nine SF Symbols weights.
///
/// Three of these are authored by the designer; the rest are derived by
/// parameter interpolation at export time. See spec 12.1 and 12.3.
public enum SymbolWeight: String, Codable, CaseIterable, Sendable {
    case ultralight
    case thin
    case light
    case regular
    case medium
    case semibold
    case bold
    case heavy
    case black

    /// The three weights the designer edits directly. See spec 12.1.
    public static let authored: [SymbolWeight] = [.ultralight, .regular, .black]

    public var isAuthored: Bool {
        Self.authored.contains(self)
    }

    /// Position along the weight axis, used to interpolate parameters for the
    /// six weights that are not authored. See spec 12.3.
    ///
    /// Ultralight is 0, Regular is 1, Black is 2, so interpolation between the
    /// authored anchors is piecewise linear in this coordinate.
    public var axisPosition: Double {
        switch self {
        case .ultralight: 0.0
        case .thin: 0.35
        case .light: 0.7
        case .regular: 1.0
        case .medium: 1.2
        case .semibold: 1.4
        case .bold: 1.6
        case .heavy: 1.8
        case .black: 2.0
        }
    }
}

/// The three SF Symbols scales.
///
/// Only Medium is authored. Small and Large are derived by rule. See spec 12.4.
public enum SymbolScale: String, Codable, CaseIterable, Sendable {
    case small
    case medium
    case large

    /// The only scale the designer edits directly. See spec 12.4.
    public static let authored: SymbolScale = .medium

    public var isAuthored: Bool {
        self == Self.authored
    }
}

/// One of the 27 weight/scale slots in a populated SF Symbols template.
///
/// See spec 12.2.
public struct SymbolSlot: Codable, Hashable, Sendable {

    public var weight: SymbolWeight
    public var scale: SymbolScale

    public init(weight: SymbolWeight, scale: SymbolScale) {
        self.weight = weight
        self.scale = scale
    }

    /// All 27 slots that a full export must populate. See spec 12.2.
    public static let all: [SymbolSlot] = SymbolScale.allCases.flatMap { scale in
        SymbolWeight.allCases.map { weight in
            SymbolSlot(weight: weight, scale: scale)
        }
    }

    /// The three slots the designer authors directly.
    public static let authored: [SymbolSlot] = SymbolWeight.authored.map {
        SymbolSlot(weight: $0, scale: .medium)
    }

    public var isAuthored: Bool {
        weight.isAuthored && scale.isAuthored
    }
}
