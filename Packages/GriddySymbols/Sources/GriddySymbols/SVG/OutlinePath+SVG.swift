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
    /// - Parameter transform: maps a point for a given master index. Per-master
    ///   rather than shared because each master sits at its own glyph origin:
    ///   normalising every master to the same left side bearing is what stops
    ///   the symbol sliding sideways as the weight changes. See ``GlyphMetrics``.
    public func svgCommandsForReconciledMasters(
        mapping transform: (Int, IconPoint) -> IconPoint
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
                result[master].append(.move(to: transform(master, start)))
            }

            let segmentCount = reference.contours[contourIndex].segments.count
            for segmentIndex in 0..<segmentCount {
                // How many pieces this segment takes in any master, and whether
                // any master curves here.
                var pieces = 1
                var anyMasterCurves = false

                for master in indices {
                    let contour = self[master].contours[contourIndex]
                    guard segmentIndex < contour.segments.count,
                          case .arc(let arc) = contour.segments[segmentIndex] else {
                        continue
                    }
                    anyMasterCurves = true
                    pieces = Swift.max(pieces, ArcToCubic.segmentCount(for: arc))
                }

                for master in indices {
                    let contour = self[master].contours[contourIndex]
                    guard segmentIndex < contour.segments.count else {
                        continue
                    }

                    switch contour.segments[segmentIndex] {
                    case .line(let from, let to):
                        // Matching command *counts* is not enough: interpolation
                        // pairs command i with command i, and a line cannot
                        // interpolate with a cubic. Where any master curves
                        // here, every master emits cubics -- a line is exactly a
                        // cubic with its controls a third and two thirds along.
                        result[master].append(contentsOf: pieceCommands(
                            from: from, to: to, pieces: pieces,
                            asCurve: anyMasterCurves,
                            transform: { transform(master, $0) }))

                    case .arc(let arc):
                        for cubic in ArcToCubic.cubics(for: arc, count: pieces) {
                            result[master].append(.cubic(
                                control1: transform(master, cubic.control1),
                                control2: transform(master, cubic.control2),
                                to: transform(master, cubic.end)))
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

    /// A straight run, emitted either as lines or as equivalent cubics.
    private func pieceCommands(from: IconPoint,
                               to: IconPoint,
                               pieces: Int,
                               asCurve: Bool,
                               transform: (IconPoint) -> IconPoint)
    -> [SVGPathCommand] {
        var commands: [SVGPathCommand] = []

        for piece in 1...pieces {
            let previous = Double(piece - 1) / Double(pieces)
            let next = Double(piece) / Double(pieces)

            func along(_ t: Double) -> IconPoint {
                IconPoint(x: from.x + (to.x - from.x) * t,
                          y: from.y + (to.y - from.y) * t)
            }

            let end = along(next)

            if asCurve {
                // Controls a third and two thirds along reproduce the straight
                // line exactly; nothing about the shape changes.
                let third = (next - previous) / 3
                commands.append(.cubic(control1: transform(along(previous + third)),
                                       control2: transform(along(next - third)),
                                       to: transform(end)))
            } else {
                commands.append(.line(to: transform(end)))
            }
        }
        return commands
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
