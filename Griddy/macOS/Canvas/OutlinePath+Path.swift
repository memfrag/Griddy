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
                append(arc, to: &path, transform: transform)
            }
        }

        path.closeSubpath()
    }

    private func append(_ arc: ArcSegment,
                        to path: inout Path,
                        transform: CanvasTransform) {
        // A full circle is one arc whose start and end angles coincide, and
        // `addArc` with equal angles draws nothing at all. Emitting it as two
        // half turns keeps it visible while preserving the sweep direction,
        // which `addEllipse` would discard -- and direction is what makes a
        // hole subtract under non-zero winding.
        let turn = 2 * Double.pi
        if abs(arc.sweep - turn) < 1e-9 {
            let half = arc.isClockwise ? -Double.pi : Double.pi
            let middle = IconAngle(radians: arc.startAngle.radians + half)
            addArc(arc, from: arc.startAngle, to: middle, to: &path, transform: transform)
            addArc(arc, from: middle, to: arc.endAngle, to: &path, transform: transform)
            return
        }
        addArc(arc, from: arc.startAngle, to: arc.endAngle,
               to: &path, transform: transform)
    }

    private func addArc(_ arc: ArcSegment,
                        from start: IconAngle,
                        to end: IconAngle,
                        to path: inout Path,
                        transform: CanvasTransform) {
        // Unit space has Y increasing upward and view space downward, so angles
        // negate and the sweep direction inverts. Getting this wrong draws the
        // complementary arc, which looks plausible until the shape is checked
        // against its own endpoints.
        path.addArc(
            center: transform.point(arc.center),
            radius: transform.length(arc.radius),
            startAngle: .radians(-start.radians),
            endAngle: .radians(-end.radians),
            clockwise: !arc.isClockwise,
            transform: .identity
        )
    }
}
