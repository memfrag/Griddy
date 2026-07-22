//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// Which construction guides the canvas draws.
///
/// An option set rather than a field per guide: there are six of them and the
/// list has grown once already. Stored as its raw value, so adding a guide
/// leaves existing documents readable. See spec 8.3.
public struct GuideSet: OptionSet, Codable, Hashable, Sendable {

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Lines every `primaryInterval` -- 1u by default.
    public static let primaryGrid = GuideSet(rawValue: 1 << 0)

    /// Subdivisions of the primary grid, 0.25u by default.
    public static let secondaryGrid = GuideSet(rawValue: 1 << 1)

    /// Apple's proportional templates for the document's design intent.
    public static let keyShapes = GuideSet(rawValue: 1 << 2)

    /// The inset region inside the margins.
    public static let safeArea = GuideSet(rawValue: 1 << 3)

    /// Baseline and capline: the horizontal edges of the cap-height box.
    ///
    /// The box itself is not drawn. Its vertical edges coincide with the design
    /// area and carry no information, and its horizontal edges duplicated these
    /// two lines exactly -- the canvas drew both, in different colours and dash
    /// patterns, which is most of why it read as cluttered.
    public static let baseline = GuideSet(rawValue: 1 << 4)

    /// The template's left and right margins: the real bound on artwork width.
    public static let margins = GuideSet(rawValue: 1 << 5)

    public static let all: GuideSet = [
        .primaryGrid, .secondaryGrid, .keyShapes, .safeArea, .baseline, .margins
    ]

    /// What a new document shows.
    ///
    /// Key shapes and the safe area are off: both are advisory, and six guide
    /// systems at once is not a canvas anyone can read.
    public static let `default`: GuideSet = [
        .primaryGrid, .secondaryGrid, .baseline, .margins
    ]
}

public extension GuideSet {

    /// Every guide, in the order the canvas menu lists them.
    static let ordered: [(guide: GuideSet, name: String)] = [
        (.primaryGrid, "Grid"),
        (.secondaryGrid, "Subdivisions"),
        (.baseline, "Baseline and Capline"),
        (.margins, "Margins"),
        (.safeArea, "Safe Area"),
        (.keyShapes, "Key Shapes")
    ]

    /// A binding-friendly accessor, so the menu can be built by iteration
    /// rather than six near-identical toggles.
    func shows(_ guide: GuideSet) -> Bool {
        contains(guide)
    }

    mutating func set(_ guide: GuideSet, to isVisible: Bool) {
        if isVisible {
            insert(guide)
        } else {
            remove(guide)
        }
    }
}
