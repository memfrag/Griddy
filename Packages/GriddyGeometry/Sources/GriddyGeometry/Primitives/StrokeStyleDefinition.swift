//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// How a primitive's centerline is stroked during construction.
///
/// These values describe the *construction* stroke. They are never written as
/// SVG stroke attributes; they are inputs to outlining. See spec 10.3 and 10.5.
public struct StrokeStyleDefinition: Codable, Hashable, Sendable {

    public var width: StrokeWidthSource

    /// A per-primitive multiplier on the resolved width.
    ///
    /// Applied to whatever ``width`` produces, so a `.systemWeight` stroke at
    /// 1.5 stays half again as heavy at *every* weight rather than becoming a
    /// fixed thickness that stops tracking the master. This is the knob for
    /// "make this one shape's line wider" without detaching it from weight
    /// propagation. One is no change. See spec 10.3.
    public var widthMultiplier: Double

    /// The cap on both ends of an open primitive, unless one end overrides it.
    public var lineCap: LineCap

    /// Per-end cap overrides for an open primitive, nil to follow ``lineCap``.
    ///
    /// A line has a distinct start and end, so its two ends can be capped
    /// differently — a round lead-in and a flat tail, say. These are line
    /// concepts; a closed shape has no ends and ignores them. See spec 10.3.
    public var startCap: LineCap?
    public var endCap: LineCap?

    public var lineJoin: LineJoin
    public var miterLimit: Double

    /// The cap actually used on the start end.
    public var resolvedStartCap: LineCap { startCap ?? lineCap }

    /// The cap actually used on the end end.
    public var resolvedEndCap: LineCap { endCap ?? lineCap }

    public static let `default` = StrokeStyleDefinition(
        width: .systemWeight,
        lineCap: .round,
        lineJoin: .round,
        miterLimit: 10
    )

    public init(width: StrokeWidthSource,
                widthMultiplier: Double = 1,
                lineCap: LineCap,
                startCap: LineCap? = nil,
                endCap: LineCap? = nil,
                lineJoin: LineJoin,
                miterLimit: Double) {
        self.width = width
        self.widthMultiplier = widthMultiplier
        self.lineCap = lineCap
        self.startCap = startCap
        self.endCap = endCap
        self.lineJoin = lineJoin
        self.miterLimit = miterLimit
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case width, widthMultiplier, lineCap, startCap, endCap
        case lineJoin, miterLimit
    }

    /// Decodes documents written before the multiplier and per-end caps
    /// existed. The multiplier takes 1; the per-end caps take nil, so both ends
    /// follow `lineCap` exactly as before.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        width = try container.decode(StrokeWidthSource.self, forKey: .width)
        widthMultiplier = try container.decodeIfPresent(
            Double.self, forKey: .widthMultiplier) ?? 1
        lineCap = try container.decode(LineCap.self, forKey: .lineCap)
        startCap = try container.decodeIfPresent(LineCap.self, forKey: .startCap)
        endCap = try container.decodeIfPresent(LineCap.self, forKey: .endCap)
        lineJoin = try container.decode(LineJoin.self, forKey: .lineJoin)
        miterLimit = try container.decode(Double.self, forKey: .miterLimit)
    }
}

/// Where a primitive's stroke width comes from.
public enum StrokeWidthSource: Codable, Hashable, Sendable {

    /// Track the active master's weight. This is the usual case, and the one
    /// that makes a primitive respond to weight propagation. See spec 12.3.
    case systemWeight

    /// A fixed width in units, identical at every weight.
    case fixed(Double)

    /// A width derived from the master's weight expansion, scaled.
    case derived(base: Double, scaleFactor: Double)
}

public enum LineCap: String, Codable, Sendable {
    case butt
    case round
    case square
}

public enum LineJoin: String, Codable, Sendable {
    case miter
    case round
    case bevel
}
