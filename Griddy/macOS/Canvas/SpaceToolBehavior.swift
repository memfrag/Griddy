//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// What the space bar does while a drawing tool is active.
///
/// Two conventions exist and designers disagree about which is right, so it is
/// a preference rather than a hardcoded choice. See spec 8.3.
public enum SpaceToolBehavior: String, CaseIterable, Codable, Sendable,
                               Identifiable, CustomStringConvertible {

    /// Hold space to use Select; release to return to the drawing tool. The
    /// convention in Figma and Sketch, where space is momentary pan.
    case momentary

    /// Tap space once to switch to Select and stay there.
    case toggle

    public var id: Self { self }

    public var description: String {
        switch self {
        case .momentary: "Hold to select"
        case .toggle: "Tap to switch"
        }
    }
}
