//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyGeometry

extension OutlinePath {

    /// Converts an analytic outline into a drawable path.
    ///
    /// Arcs stay arcs: nothing here flattens a curve into line segments. The
    /// conversion is purely a change of coordinate space. See spec 10.5.
    func cgPath(transform: CanvasTransform) -> Path {
        var path = Path()
        for contour in contours {
            contour.append(to: &path, transform: transform)
        }
        return path
    }
}

extension OutlineContour {

    func append(to path: inout Path, transform: CanvasTransform) {
        guard let first = segments.first else {
            return
        }

        path.move(to: transform.point(first.start))

        for segment in segments {
            switch segment {
            case .line(_, let to):
                path.addLine(to: transform.point(to))

            case .arc(let arc):
                // Unit space has Y increasing upward and view space downward,
                // so angles negate and the sweep direction inverts. Getting
                // this wrong draws the complementary arc, which looks plausible
                // until the shape is checked against its own endpoints.
                path.addArc(
                    center: transform.point(arc.center),
                    radius: transform.length(arc.radius),
                    startAngle: .radians(-arc.startAngle.radians),
                    endAngle: .radians(-arc.endAngle.radians),
                    clockwise: !arc.isClockwise,
                    transform: .identity
                )
            }
        }

        path.closeSubpath()
    }
}
