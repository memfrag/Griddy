//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

/// Serialises path commands back to an SVG `d` attribute.
public enum SVGPathWriter {

    /// Writes commands as absolute SVG path data.
    ///
    /// Always absolute, never the relative shorthand: the output is meant to be
    /// diffable and inspectable, and relative coordinates make a path
    /// impossible to read without simulating it.
    public static func write(_ commands: [SVGPathCommand],
                             precision: Int = 4) -> String {
        var pieces: [String] = []

        for command in commands {
            switch command {
            case .move(let to):
                pieces.append("M\(number(to.x, precision)),\(number(to.y, precision))")
            case .line(let to):
                pieces.append("L\(number(to.x, precision)),\(number(to.y, precision))")
            case .cubic(let control1, let control2, let to):
                pieces.append("C\(number(control1.x, precision)),"
                              + "\(number(control1.y, precision)) "
                              + "\(number(control2.x, precision)),"
                              + "\(number(control2.y, precision)) "
                              + "\(number(to.x, precision)),\(number(to.y, precision))")
            case .close:
                pieces.append("Z")
            }
        }
        return pieces.joined(separator: " ")
    }

    /// Formats a coordinate the same way path data does, for attributes written
    /// outside a path -- margin guide positions, for instance.
    public static func number(_ value: Double) -> String {
        number(value, 4)
    }

    /// Formats a coordinate without trailing zeros, so paths stay compact and
    /// compare cleanly between exports.
    private static func number(_ value: Double, _ precision: Int) -> String {
        let rounded = (value * pow(10, Double(precision))).rounded()
            / pow(10, Double(precision))

        if rounded == rounded.rounded(), abs(rounded) < 1e15 {
            return String(Int(rounded))
        }
        return String(format: "%.\(precision)g", rounded)
    }
}

extension SVGPathCommand {

    /// The command with every point mapped through a transform.
    public func mapped(_ transform: (IconPoint) -> IconPoint) -> SVGPathCommand {
        switch self {
        case .move(let to):
            .move(to: transform(to))
        case .line(let to):
            .line(to: transform(to))
        case .cubic(let control1, let control2, let to):
            .cubic(control1: transform(control1),
                   control2: transform(control2),
                   to: transform(to))
        case .close:
            .close
        }
    }
}
