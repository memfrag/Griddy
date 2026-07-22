//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

extension OutlinePath {

    /// The outline as SVG path commands, with every point mapped.
    ///
    /// Arcs become cubics here and nowhere earlier. Griddy keeps circular arcs
    /// exact all the way through outlining and boolean resolution, because that
    /// is what makes intersection analytic; the conversion happens at the last
    /// possible moment, on the way out. See spec 10.5.
    public func svgCommands(mapping transform: (IconPoint) -> IconPoint)
    -> [SVGPathCommand] {
        var commands: [SVGPathCommand] = []

        for contour in contours {
            guard let first = contour.segments.first else {
                continue
            }
            commands.append(.move(to: transform(first.start)))

            for segment in contour.segments {
                switch segment {
                case .line(_, let to):
                    commands.append(.line(to: transform(to)))

                case .arc(let arc):
                    for cubic in ArcToCubic.cubics(for: arc) {
                        commands.append(.cubic(control1: transform(cubic.control1),
                                               control2: transform(cubic.control2),
                                               to: transform(cubic.end)))
                    }
                }
            }
            commands.append(.close)
        }
        return commands
    }
}
