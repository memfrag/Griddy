//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

/// What the preview strip shows. See spec 7.5 and 8.7.
public struct PreviewSettings: Codable, Hashable, Sendable {

    /// Point sizes rendered in the preview strip.
    public var pointSizes: [Double]

    /// System symbol names shown alongside the artwork for visual comparison.
    ///
    /// These are resolved through `NSImage(systemSymbolName:)` at render time.
    /// Griddy never reads other documents. See spec 8.3.
    public var comparisonSymbolNames: [String]

    public var showsLightBackground: Bool
    public var showsDarkBackground: Bool

    public static let `default` = PreviewSettings(
        pointSizes: [12, 14, 17, 20, 24, 32],
        comparisonSymbolNames: ["magnifyingglass", "photo", "gear"],
        showsLightBackground: true,
        showsDarkBackground: true
    )

    public init(pointSizes: [Double],
                comparisonSymbolNames: [String],
                showsLightBackground: Bool,
                showsDarkBackground: Bool) {
        self.pointSizes = pointSizes
        self.comparisonSymbolNames = comparisonSymbolNames
        self.showsLightBackground = showsLightBackground
        self.showsDarkBackground = showsDarkBackground
    }
}

/// How the document is written to SF Symbols SVG. See spec 14.4.
public struct ExportSettings: Codable, Hashable, Sendable {

    public var weightPropagation: WeightPropagationSettings

    /// Stroke width multipliers applied when deriving the Small and Large
    /// scale slots from the authored Medium construction.
    ///
    /// - Note: Provisional. Spec 12.4 records these as an open question; they
    ///   need tuning against real Apple symbols at matched sizes.
    public var smallScaleStrokeCompensation: Double
    public var largeScaleStrokeCompensation: Double

    public static let `default` = ExportSettings(
        weightPropagation: .default,
        smallScaleStrokeCompensation: 1.08,
        largeScaleStrokeCompensation: 0.94
    )

    public init(weightPropagation: WeightPropagationSettings,
                smallScaleStrokeCompensation: Double,
                largeScaleStrokeCompensation: Double) {
        self.weightPropagation = weightPropagation
        self.smallScaleStrokeCompensation = smallScaleStrokeCompensation
        self.largeScaleStrokeCompensation = largeScaleStrokeCompensation
    }

    public func strokeCompensation(for scale: SymbolScale) -> Double {
        switch scale {
        case .small: smallScaleStrokeCompensation
        case .medium: 1.0
        case .large: largeScaleStrokeCompensation
        }
    }
}
