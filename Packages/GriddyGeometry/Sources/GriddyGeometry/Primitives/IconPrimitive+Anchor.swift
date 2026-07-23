//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

extension IconPrimitive {

    /// The point a primitive is positioned by.
    ///
    /// A circle or arc is anchored at its centre, a line at its midpoint, and a
    /// rectangular shape at the centre of its bounds. Constraints that talk
    /// about position -- centring, concentricity, fixed distance -- act on this
    /// point, so they do not each need to know about every primitive kind.
    public var anchor: IconPoint? {
        switch self {
        case .line(let line):
            IconPoint(x: (line.start.x + line.end.x) / 2,
                      y: (line.start.y + line.end.y) / 2)
        case .arc(let arc):
            arc.center
        case .circle(let circle):
            circle.center
        case .roundedRect(let rect):
            rect.bounds.center
        case .capsule(let capsule):
            capsule.bounds.center
        case .polyline, .symmetricPath:
            PrimitiveGeometry.bounds(of: self)?.center
        case .compound, .importedPath:
            nil
        }
    }

    /// The primitive moved so its anchor lands on a point.
    public func movingAnchor(to point: IconPoint) -> IconPrimitive {
        guard let anchor else {
            return self
        }
        return translated(by: anchor.vector(to: point))
    }

    /// The radius of a primitive that has one.
    public var radius: Double? {
        switch self {
        case .circle(let circle): circle.radius
        case .arc(let arc): arc.radius
        default: nil
        }
    }

    /// The primitive with its radius changed, where that is meaningful.
    public func settingRadius(_ newRadius: Double) -> IconPrimitive {
        let clamped = max(0, newRadius)
        switch self {
        case .circle(var circle):
            circle.radius = clamped
            return .circle(circle)
        case .arc(var arc):
            arc.radius = clamped
            return .arc(arc)
        default:
            return self
        }
    }

    /// The direction a linear primitive points in, if it has one.
    public var direction: IconVector? {
        guard case .line(let line) = self else {
            return nil
        }
        return line.start.vector(to: line.end).normalized
    }

    /// A linear primitive rotated about its midpoint to point along `direction`.
    public func settingDirection(_ direction: IconVector) -> IconPrimitive {
        guard case .line(var line) = self,
              let unit = direction.normalized,
              let anchor else {
            return self
        }
        let halfLength = line.length / 2
        line.start = anchor.offset(by: unit.scaled(by: -halfLength))
        line.end = anchor.offset(by: unit.scaled(by: halfLength))
        return .line(line)
    }

    /// The length of a primitive that has a natural one.
    ///
    /// A line's length is the distance between its ends. Nothing else reports
    /// one: a circle's "length" would be ambiguous (diameter? circumference?),
    /// and equal-length only ever relates lines.
    public var length: Double? {
        guard case .line(let line) = self else {
            return nil
        }
        return line.length
    }

    /// A line rescaled about its midpoint to a new length, keeping direction.
    ///
    /// A no-op on anything that is not a line, and on a zero-length line, which
    /// has no direction to preserve.
    public func settingLength(_ newLength: Double) -> IconPrimitive {
        guard case .line(var line) = self,
              let unit = line.start.vector(to: line.end).normalized,
              let anchor else {
            return self
        }
        let half = max(0, newLength) / 2
        line.start = anchor.offset(by: unit.scaled(by: -half))
        line.end = anchor.offset(by: unit.scaled(by: half))
        return .line(line)
    }

    /// The primitive reflected across an axis.
    public func mirrored(across axis: SymmetryAxis, at position: Double) -> IconPrimitive {
        guard let anchor else {
            return self
        }
        let target = switch axis {
        case .vertical: IconPoint(x: 2 * position - anchor.x, y: anchor.y)
        case .horizontal: IconPoint(x: anchor.x, y: 2 * position - anchor.y)
        }
        return movingAnchor(to: target)
    }
}
