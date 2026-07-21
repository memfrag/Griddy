//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// The attributes every primitive carries, independent of its geometry.
///
/// Layer membership is deliberately *not* here. Layers own an ordered list of
/// primitive identifiers instead, so a primitive cannot disagree with the layer
/// that claims it. See spec 13.4.
public struct PrimitiveAttributes: Codable, Hashable, Sendable {

    public var isVisible: Bool

    /// Whether this primitive contributes geometry to the exported SVG.
    ///
    /// Construction aids can live in the document without reaching export.
    public var participatesInExport: Bool

    public var stroke: StrokeStyleDefinition

    public static let `default` = PrimitiveAttributes(
        isVisible: true,
        participatesInExport: true,
        stroke: .default
    )

    public init(isVisible: Bool,
                participatesInExport: Bool,
                stroke: StrokeStyleDefinition) {
        self.isVisible = isVisible
        self.participatesInExport = participatesInExport
        self.stroke = stroke
    }
}
