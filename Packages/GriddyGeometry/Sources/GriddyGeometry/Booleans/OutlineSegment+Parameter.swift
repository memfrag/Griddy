//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

extension ArcSegment {

    /// The angle at parameter `t`, where 0 is the start and 1 the end.
    public func angle(at t: Double) -> IconAngle {
        let signedSweep = isClockwise ? -sweep : sweep
        return IconAngle(radians: startAngle.radians + signedSweep * t)
    }

    /// The parameter at which the arc passes through an angle, or `nil` when
    /// the angle lies outside the sweep.
    public func parameter(atAngle angle: IconAngle) -> Double? {
        let turn = 2 * Double.pi
        let offset = isClockwise
            ? startAngle.radians - angle.radians
            : angle.radians - startAngle.radians

        var normalized = offset.truncatingRemainder(dividingBy: turn)
        if normalized < 0 {
            normalized += turn
        }

        let t = normalized / sweep
        return t <= 1 + 1e-9 ? min(1, t) : nil
    }
}

extension OutlineSegment {

    /// The point at parameter `t` in `0...1`.
    public func point(at t: Double) -> IconPoint {
        switch self {
        case .line(let from, let to):
            IconPoint(x: from.x + (to.x - from.x) * t,
                      y: from.y + (to.y - from.y) * t)
        case .arc(let arc):
            arc.point(atAngle: arc.angle(at: t))
        }
    }

    /// The direction of travel at parameter `t`, normalised where possible.
    public func tangent(at t: Double) -> IconVector {
        switch self {
        case .line(let from, let to):
            from.vector(to: to).normalized ?? .zero
        case .arc(let arc):
            // The tangent of a circle is perpendicular to its radius, pointing
            // the way the sweep travels.
            {
                let radial = arc.angle(at: t).direction
                let tangent = radial.perpendicular
                return arc.isClockwise ? tangent.scaled(by: -1) : tangent
            }()
        }
    }

    /// The segment restricted to a parameter range.
    public func portion(from start: Double, to end: Double) -> OutlineSegment? {
        guard end - start > 1e-12 else {
            return nil
        }

        switch self {
        case .line:
            return .line(from: point(at: start), to: point(at: end))
        case .arc(let arc):
            return .arc(ArcSegment(center: arc.center,
                                   radius: arc.radius,
                                   startAngle: arc.angle(at: start),
                                   endAngle: arc.angle(at: end),
                                   isClockwise: arc.isClockwise))
        }
    }

    /// The segment cut at a set of parameters.
    ///
    /// Parameters outside `0...1`, duplicates, and pieces of no length are
    /// discarded, so a segment with no usable cuts comes back unchanged.
    public func split(at parameters: [Double]) -> [OutlineSegment] {
        let cuts = ([0, 1] + parameters)
            .filter { $0 >= -1e-9 && $0 <= 1 + 1e-9 }
            .map { min(1, max(0, $0)) }
            .sorted()

        var pieces: [OutlineSegment] = []
        for index in 0..<(cuts.count - 1) {
            if let piece = portion(from: cuts[index], to: cuts[index + 1]) {
                pieces.append(piece)
            }
        }
        return pieces.isEmpty ? [self] : pieces
    }
}
