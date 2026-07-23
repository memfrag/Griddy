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

    public var lineCap: LineCap
    public var lineJoin: LineJoin
    public var miterLimit: Double

    public static let `default` = StrokeStyleDefinition(
        width: .systemWeight,
        lineCap: .round,
        lineJoin: .round,
        miterLimit: 10
    )

    public init(width: StrokeWidthSource,
                widthMultiplier: Double = 1,
                lineCap: LineCap,
                lineJoin: LineJoin,
                miterLimit: Double) {
        self.width = width
        self.widthMultiplier = widthMultiplier
        self.lineCap = lineCap
        self.lineJoin = lineJoin
        self.miterLimit = miterLimit
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case width, widthMultiplier, lineCap, lineJoin, miterLimit
    }

    /// Decodes documents written before the multiplier existed, which take 1.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        width = try container.decode(StrokeWidthSource.self, forKey: .width)
        widthMultiplier = try container.decodeIfPresent(
            Double.self, forKey: .widthMultiplier) ?? 1
        lineCap = try container.decode(LineCap.self, forKey: .lineCap)
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
