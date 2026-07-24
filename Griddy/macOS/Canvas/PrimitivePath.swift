//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyGeometry

/// Builds Core Graphics paths from semantic primitives.
///
/// Kept separate from the model types so the document never depends on a
/// drawing framework. See spec 23.2.
///
/// These are *centerline* paths. Milestone 3 adds analytic outlining and the
/// boolean solver, which is what export uses; the canvas approximates the
/// rendered result by stroking these with the resolved width.
enum PrimitivePath {

    static func path(for primitive: IconPrimitive,
                     transform: CanvasTransform) -> Path {
        var path = Path()

        switch primitive {
        case .line(let line):
            path.move(to: transform.point(line.start))
            path.addLine(to: transform.point(line.end))

        case .circle(let circle):
            path.addEllipse(in: transform.rect(circle.bounds))

        case .arc(let arc):
            addArc(arc, to: &path, transform: transform)

        case .roundedRect(let rect):
            path.addRoundedRect(
                in: transform.rect(rect.bounds),
                cornerSize: CGSize(
                    width: transform.length(rect.effectiveCornerRadius),
                    height: transform.length(rect.effectiveCornerRadius)
                ),
                style: .continuous
            )

        case .capsule(let capsule):
            path.addRoundedRect(
                in: transform.rect(capsule.bounds),
                cornerSize: CGSize(
                    width: transform.length(capsule.cornerRadius),
                    height: transform.length(capsule.cornerRadius)
                ),
                style: .circular
            )

        case .polyline(let polyline):
            if polyline.isSmooth {
                // The selection outline should follow the same biarc curve the
                // artwork does, not the straight chord between points.
                addCenterline(Biarc.fit(through: polyline.points,
                                        closed: polyline.isClosed,
                                        inSmoothness: polyline.resolvedInSmoothness,
                                        outSmoothness: polyline.resolvedOutSmoothness,
                                        handles: polyline.resolvedHandles),
                              to: &path, transform: transform)
            } else {
                addPoints(polyline.points,
                          isClosed: polyline.isClosed,
                          to: &path,
                          transform: transform)
            }

        case .symmetricPath(let symmetric):
            addPoints(symmetric.points + symmetric.mirroredPoints,
                      isClosed: true,
                      to: &path,
                      transform: transform)

        case .compound, .importedPath:
            // Compounds resolve through their children, and imported path data
            // needs the SVG path parser that arrives with import.
            break
        }

        return path
    }

    private static func addArc(_ arc: ArcPrimitive,
                               to path: inout Path,
                               transform: CanvasTransform) {
        // Unit space has Y increasing upward and view space has it increasing
        // downward, so a counterclockwise sweep in the document is a clockwise
        // sweep on screen. Getting this backwards draws the complementary arc,
        // which looks plausible until you check the angles.
        path.addArc(
            center: transform.point(arc.center),
            radius: transform.length(arc.radius),
            startAngle: .radians(-arc.startAngle.radians),
            endAngle: .radians(-arc.endAngle.radians),
            clockwise: !arc.isClockwise
        )
    }

    /// Draws a biarc centerline (arcs and lines) without closing it.
    private static func addCenterline(_ segments: [OutlineSegment],
                                      to path: inout Path,
                                      transform: CanvasTransform) {
        guard let first = segments.first else {
            return
        }
        path.move(to: transform.point(first.start))
        for segment in segments {
            switch segment {
            case .line(_, let to):
                path.addLine(to: transform.point(to))
            case .arc(let arc):
                path.addArc(
                    center: transform.point(arc.center),
                    radius: transform.length(arc.radius),
                    startAngle: .radians(-arc.startAngle.radians),
                    endAngle: .radians(-arc.endAngle.radians),
                    clockwise: !arc.isClockwise)
            }
        }
    }

    private static func addPoints(_ points: [IconPoint],
                                  isClosed: Bool,
                                  to path: inout Path,
                                  transform: CanvasTransform) {
        guard let first = points.first else {
            return
        }
        path.move(to: transform.point(first))
        for point in points.dropFirst() {
            path.addLine(to: transform.point(point))
        }
        if isClosed {
            path.closeSubpath()
        }
    }
}
