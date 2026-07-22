//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

extension Array where Element == OutlinePath {

    /// Converts reconciled masters to SVG commands that stay reconciled.
    ///
    /// Reconciliation makes the masters agree on outline segments, but an arc
    /// expands into a number of cubics that follows its sweep, so corresponding
    /// arcs of slightly different sweep would produce different command counts
    /// and quietly undo the work. Converting the masters together, using the
    /// largest cubic count each corresponding segment needs, keeps them in step.
    ///
    /// The caller must have run ``OutlineCompatibility/reconcile(_:)`` first;
    /// this assumes the structures already match.
    public func svgCommandsForReconciledMasters(
        mapping transform: (IconPoint) -> IconPoint
    ) -> [[SVGPathCommand]] {
        guard let reference = first else {
            return []
        }

        // Spelled out rather than `Array(repeating:count:)`, which resolves to
        // this extension's own Self inside it.
        var result = [[SVGPathCommand]](repeating: [], count: count)

        for contourIndex in reference.contours.indices {
            // Start every master's contour at its own first point.
            for master in indices {
                guard let start = self[master].contours[contourIndex]
                    .segments.first?.start else {
                    continue
                }
                result[master].append(.move(to: transform(start)))
            }

            let segmentCount = reference.contours[contourIndex].segments.count
            for segmentIndex in 0..<segmentCount {
                // The number of pieces this segment takes in any master.
                var pieces = 1
                for master in indices {
                    let contour = self[master].contours[contourIndex]
                    guard segmentIndex < contour.segments.count,
                          case .arc(let arc) = contour.segments[segmentIndex] else {
                        continue
                    }
                    pieces = Swift.max(pieces, ArcToCubic.segmentCount(for: arc))
                }

                for master in indices {
                    let contour = self[master].contours[contourIndex]
                    guard segmentIndex < contour.segments.count else {
                        continue
                    }

                    switch contour.segments[segmentIndex] {
                    case .line(_, let to):
                        // A line matched against an arc still has to yield the
                        // same number of commands, so it is subdivided too.
                        let from = contour.segments[segmentIndex].start
                        for piece in 1...pieces {
                            let t = Double(piece) / Double(pieces)
                            result[master].append(.line(to: transform(
                                IconPoint(x: from.x + (to.x - from.x) * t,
                                          y: from.y + (to.y - from.y) * t))))
                        }

                    case .arc(let arc):
                        for cubic in ArcToCubic.cubics(for: arc, count: pieces) {
                            result[master].append(.cubic(
                                control1: transform(cubic.control1),
                                control2: transform(cubic.control2),
                                to: transform(cubic.end)))
                        }
                    }
                }
            }

            for master in indices {
                result[master].append(.close)
            }
        }
        return result
    }
}

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
