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
                lineCap: LineCap,
                lineJoin: LineJoin,
                miterLimit: Double) {
        self.width = width
        self.lineCap = lineCap
        self.lineJoin = lineJoin
        self.miterLimit = miterLimit
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
