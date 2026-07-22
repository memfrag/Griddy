//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

/// A construction guide used to harmonise visual size across icons.
///
/// See spec 9.5.
public struct KeyShape: Codable, Hashable, Sendable, Identifiable {

    public var id: UUID
    public var name: String
    public var kind: KeyShapeKind
    public var bounds: IconRect
    public var opticalOvershoot: Double
    public var recommendedAttachmentPoints: [IconPoint]
    public var maximumExtent: IconRect?
    public var isVisible: Bool

    public init(id: UUID = UUID(),
                name: String,
                kind: KeyShapeKind,
                bounds: IconRect,
                opticalOvershoot: Double = 0,
                recommendedAttachmentPoints: [IconPoint] = [],
                maximumExtent: IconRect? = nil,
                isVisible: Bool = true) {
        self.id = id
        self.name = name
        self.kind = kind
        self.bounds = bounds
        self.opticalOvershoot = opticalOvershoot
        self.recommendedAttachmentPoints = recommendedAttachmentPoints
        self.maximumExtent = maximumExtent
        self.isVisible = isVisible
    }
}

public enum KeyShapeKind: String, Codable, Sendable {
    case circle
    case square
    case horizontalRectangle
    case verticalRectangle
    case customPath
}

public struct KeyShapeSet: Codable, Hashable, Sendable {

    public var circle: KeyShape
    public var square: KeyShape
    public var horizontalRectangle: KeyShape
    public var verticalRectangle: KeyShape
    public var customShapes: [KeyShape]

    public init(circle: KeyShape,
                square: KeyShape,
                horizontalRectangle: KeyShape,
                verticalRectangle: KeyShape,
                customShapes: [KeyShape] = []) {
        self.circle = circle
        self.square = square
        self.horizontalRectangle = horizontalRectangle
        self.verticalRectangle = verticalRectangle
        self.customShapes = customShapes
    }

    public var all: [KeyShape] {
        [circle, square, horizontalRectangle, verticalRectangle] + customShapes
    }

    /// The key shape a design intent points at, if any. See spec 9.4.
    public func shape(for intent: SymbolDesignIntent) -> KeyShape? {
        switch intent {
        case .circular: circle
        case .square: square
        case .wide: horizontalRectangle
        case .tall: verticalRectangle
        case .irregular: nil
        }
    }

    /// The default key shapes for a coordinate system.
    ///
    /// The proportions are centred on the canvas and sized so that each shape
    /// occupies a comparable optical area, which is the point of key shapes.
    ///
    /// - Note: These proportions are provisional. They need tuning against real
    ///   Apple symbols, in the same pass that resolves the scale compensation
    ///   factors in spec 12.4.
    public static func `default`(for coordinateSystem: CoordinateSystem) -> KeyShapeSet {
        let canvas = coordinateSystem.capHeightBox
        let center = canvas.center

        func centered(width: Double, height: Double) -> IconRect {
            IconRect(x: center.x - width / 2,
                     y: center.y - height / 2,
                     width: width,
                     height: height)
        }

        return KeyShapeSet(
            circle: KeyShape(name: "Circle",
                             kind: .circle,
                             bounds: centered(width: 13, height: 13),
                             opticalOvershoot: 0.25),
            square: KeyShape(name: "Square",
                             kind: .square,
                             bounds: centered(width: 11.5, height: 11.5)),
            horizontalRectangle: KeyShape(name: "Horizontal Rectangle",
                                          kind: .horizontalRectangle,
                                          bounds: centered(width: 14, height: 9.5)),
            verticalRectangle: KeyShape(name: "Vertical Rectangle",
                                        kind: .verticalRectangle,
                                        bounds: centered(width: 9.5, height: 14))
        )
    }
}
