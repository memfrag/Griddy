//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

extension TemplateMetrics {

    /// Metrics for a new, empty document.
    ///
    /// These are **measured from a real SF Symbols template v7.0**, not
    /// invented: baseline and capline are the `Baseline-S` and `Capline-S`
    /// guides, giving a cap height of 70.459 template units and therefore a
    /// unit of 4.4037. The left margin is the leftmost margin guide.
    ///
    /// - Note: This still stands in for loading the bundled blank template
    ///   through the importer, which is how spec 7.1 wants a new document
    ///   created -- one code path shared with import. The seam is unchanged:
    ///   everything downstream consumes `TemplateMetrics`, so swapping the
    ///   constant for parsed values changes nothing else. What has changed is
    ///   that the numbers are now real, so a new document has the same
    ///   coordinate system as an imported one.
    public static let blankTemplate = TemplateMetrics(
        baselineY: 95.215,
        caplineY: 24.756,
        leftMarginX: 241.815,
        alignmentRects: [
            .small: TemplateRect(x: 241.815, y: 24.756,
                                 width: 109.792, height: 70.459),
            .medium: TemplateRect(x: 241.815, y: 454.755,
                                  width: 109.792, height: 70.460),
            .large: TemplateRect(x: 241.815, y: 884.755,
                                 width: 109.792, height: 70.460)
        ]
    )

}
