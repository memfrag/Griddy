//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

extension TemplateMetrics {

    /// Placeholder metrics standing in for the bundled blank template.
    ///
    /// - Important: These are **provisional round numbers, not Apple's real
    ///   template values.** Milestone 5 adds the SVG parser, at which point a
    ///   new document loads `Resources/BlankSymbolTemplate.svg` through the
    ///   ordinary importer and these metrics are read from the file rather than
    ///   hardcoded here. See spec 7.1 and 14.2.
    ///
    ///   The seam is deliberate: everything downstream already consumes
    ///   `TemplateMetrics`, so replacing this constant with parsed values
    ///   changes nothing else.
    ///
    ///   A cap height of 100 makes one unit exactly 6.25 template units.
    public static let provisionalBlankTemplate = TemplateMetrics(
        baselineY: 100,
        caplineY: 0,
        leftMarginX: 0,
        alignmentRects: [
            .small: TemplateRect(x: 0, y: 0, width: 100, height: 100),
            .medium: TemplateRect(x: 0, y: 0, width: 100, height: 100),
            .large: TemplateRect(x: 0, y: 0, width: 100, height: 100)
        ]
    )
}
