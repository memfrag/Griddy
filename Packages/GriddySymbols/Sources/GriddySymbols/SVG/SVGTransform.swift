//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

/// A 2D affine transform from an SVG `transform` attribute.
///
/// SF Symbols templates position each variant group with one of these and keep
/// the path data in local coordinates, so a path read without its accumulated
/// ancestor transforms lands nowhere near where it belongs.
public struct SVGTransform: Equatable, Sendable {

    // The SVG matrix (a b c d e f), applied as:
    //   x' = a·x + c·y + e
    //   y' = b·x + d·y + f
    public var a, b, c, d, e, f: Double

    public static let identity = SVGTransform(a: 1, b: 0, c: 0, d: 1, e: 0, f: 0)

    public init(a: Double, b: Double, c: Double,
                d: Double, e: Double, f: Double) {
        self.a = a; self.b = b; self.c = c
        self.d = d; self.e = e; self.f = f
    }

    public static func translate(x: Double, y: Double) -> SVGTransform {
        SVGTransform(a: 1, b: 0, c: 0, d: 1, e: x, f: y)
    }

    public static func scale(x: Double, y: Double) -> SVGTransform {
        SVGTransform(a: x, b: 0, c: 0, d: y, e: 0, f: 0)
    }

    public static func rotate(degrees: Double) -> SVGTransform {
        let radians = degrees * .pi / 180
        return SVGTransform(a: cos(radians), b: sin(radians),
                            c: -sin(radians), d: cos(radians),
                            e: 0, f: 0)
    }

    /// `self` followed by `other`, as nesting one group inside another does.
    public func concatenated(with other: SVGTransform) -> SVGTransform {
        SVGTransform(
            a: a * other.a + b * other.c,
            b: a * other.b + b * other.d,
            c: c * other.a + d * other.c,
            d: c * other.b + d * other.d,
            e: e * other.a + f * other.c + other.e,
            f: e * other.b + f * other.d + other.f
        )
    }

    public func apply(to point: IconPoint) -> IconPoint {
        IconPoint(x: a * point.x + c * point.y + e,
                  y: b * point.x + d * point.y + f)
    }

    // MARK: Parsing

    /// Parses a `transform` attribute.
    ///
    /// Handles the forms Apple's templates use — `translate` and `matrix` — plus
    /// `scale` and `rotate`. Several transforms in one attribute compose left to
    /// right. Anything unrecognised is skipped rather than failing the import,
    /// since an unknown transform on template furniture should not stop the
    /// artwork being read.
    public static func parse(_ string: String) -> SVGTransform {
        var result = SVGTransform.identity

        let pattern = #"(\w+)\s*\(([^)]*)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return result
        }

        let range = NSRange(string.startIndex..., in: string)
        for match in regex.matches(in: string, range: range) {
            guard let nameRange = Range(match.range(at: 1), in: string),
                  let argsRange = Range(match.range(at: 2), in: string) else {
                continue
            }

            let name = String(string[nameRange])
            let numbers = String(string[argsRange])
                .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" })
                .compactMap { Double($0) }

            let step: SVGTransform? = switch name {
            case "translate" where numbers.count >= 1:
                .translate(x: numbers[0], y: numbers.count > 1 ? numbers[1] : 0)
            case "matrix" where numbers.count >= 6:
                SVGTransform(a: numbers[0], b: numbers[1], c: numbers[2],
                             d: numbers[3], e: numbers[4], f: numbers[5])
            case "scale" where numbers.count >= 1:
                .scale(x: numbers[0], y: numbers.count > 1 ? numbers[1] : numbers[0])
            case "rotate" where numbers.count >= 1:
                .rotate(degrees: numbers[0])
            default:
                nil
            }

            if let step {
                result = step.concatenated(with: result)
            }
        }
        return result
    }
}

extension SVGElement {

    /// This element's own transform, identity when it has none.
    public var transform: SVGTransform {
        attributes["transform"].map(SVGTransform.parse) ?? .identity
    }

    /// Walks the tree carrying the accumulated transform to each element.
    ///
    /// `inherited` is the transform in effect for this element's *parent*; this
    /// element's own transform is combined on top. Plain `descendants(where:)`
    /// loses ancestry, which is exactly what a transform depends on.
    public func walk(accumulating inherited: SVGTransform = .identity,
                     visit: (SVGElement, SVGTransform) -> Void) {
        walk(withEffectiveTransform: transform.concatenated(with: inherited),
             visit: visit)
    }

    /// Walks the tree given the transform already in effect *for this element*,
    /// its own transform included.
    ///
    /// Use this when an element has been located by a previous walk, which
    /// already combined its transform. Passing that value back to
    /// ``walk(accumulating:visit:)`` would apply the element's own transform a
    /// second time, silently offsetting everything beneath it by exactly one
    /// extra translation.
    public func walk(withEffectiveTransform effective: SVGTransform,
                     visit: (SVGElement, SVGTransform) -> Void) {
        visit(self, effective)
        for child in children {
            child.walk(accumulating: effective, visit: visit)
        }
    }
}
