//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// A stable identity for a primitive.
///
/// Identity must survive across every weight master, because per-master
/// differences are represented as adjustments keyed by this value rather than
/// as unrelated geometry. See spec 10.2.
public struct PrimitiveID: Codable, Hashable, Sendable {

    public var rawValue: UUID

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

extension PrimitiveID: CustomStringConvertible {

    public var description: String {
        rawValue.uuidString
    }
}
