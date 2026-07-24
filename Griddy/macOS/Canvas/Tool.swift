//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyGeometry

/// The active drawing tool.
///
/// Griddy has tools, not modes: the toolbar selection is the only editing state
/// and everything else stays visible. See spec 8.4.
enum Tool: String, CaseIterable, Identifiable {

    case select
    case line
    case arc
    case circle
    case roundedRect
    case capsule
    case pen
    case curve

    var id: Self { self }

    var label: String {
        switch self {
        case .select: "Select"
        case .line: "Line"
        case .arc: "Arc"
        case .circle: "Circle"
        case .roundedRect: "Rounded Rectangle"
        case .capsule: "Capsule"
        case .pen: "Pen"
        case .curve: "Curve"
        }
    }

    var systemImage: String {
        switch self {
        case .select: "cursorarrow"
        case .line: "line.diagonal"
        case .arc: "circle.bottomhalf.filled"
        case .circle: "circle"
        case .roundedRect: "rectangle.roundedtop"
        case .capsule: "capsule"
        case .pen: "point.topleft.down.to.point.bottomright.curvepath"
        case .curve: "scribble.variable"
        }
    }

    var keyboardShortcut: KeyEquivalent {
        switch self {
        case .select: "v"
        case .line: "l"
        case .arc: "a"
        case .circle: "o"
        case .roundedRect: "r"
        case .capsule: "c"
        case .pen: "p"
        case .curve: "b"
        }
    }

    /// Whether this tool creates geometry by dragging.
    var isDrawingTool: Bool {
        self != .select
    }

    /// Whether this tool builds a path from a series of clicks rather than a
    /// single drag. Path tools share one point-collecting interaction.
    var isPathTool: Bool {
        self == .pen || self == .curve
    }

    /// Whether a path tool joins its points with a smooth biarc spline rather
    /// than straight segments.
    var makesSmoothPath: Bool {
        self == .curve
    }

    /// Builds a primitive from a drag.
    ///
    /// Circles and arcs are drawn from the centre outward, which suits a grid
    /// where shapes are usually centred on an intersection. Rectangles and
    /// capsules are drawn corner to corner, which suits bounding a region.
    /// Returns `nil` for a drag too short to describe a shape.
    func makePrimitive(from start: IconPoint, to end: IconPoint) -> IconPrimitive? {
        let distance = start.distance(to: end)
        let bounds = PrimitiveGeometry.bounds(containing: [start, end])
            ?? IconRect(origin: start, size: .zero)

        switch self {
        case .select:
            return nil

        case .line:
            guard distance > .ulpOfOne else {
                return nil
            }
            return .line(LinePrimitive(start: start, end: end))

        case .circle:
            guard distance > .ulpOfOne else {
                return nil
            }
            return .circle(CirclePrimitive(center: start, radius: distance))

        case .arc:
            guard distance > .ulpOfOne else {
                return nil
            }
            // A half circle facing the drag direction: a usable default that
            // reads clearly on canvas and is easy to retune in the inspector.
            let direction = start.vector(to: end)
            let facing = atan2(direction.dy, direction.dx)
            return .arc(ArcPrimitive(
                center: start,
                radius: distance,
                startAngle: IconAngle(radians: facing - .pi / 2),
                endAngle: IconAngle(radians: facing + .pi / 2)
            ))

        case .roundedRect:
            guard bounds.size.width > .ulpOfOne, bounds.size.height > .ulpOfOne else {
                return nil
            }
            let radius = min(bounds.size.width, bounds.size.height) * 0.25
            return .roundedRect(RoundedRectPrimitive(bounds: bounds,
                                                     cornerRadius: radius))

        case .capsule:
            guard bounds.size.width > .ulpOfOne, bounds.size.height > .ulpOfOne else {
                return nil
            }
            return .capsule(CapsulePrimitive(bounds: bounds))

        case .pen, .curve:
            // Path tools do not build from a single drag; they collect clicks.
            return nil
        }
    }
}
