//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// Converts stroked centerlines into filled outlines.
///
/// This is the step that makes export possible at all: Griddy authors
/// centerlines with a width, but SF Symbols templates contain filled paths and
/// carry no stroke attributes. See spec 10.5.
///
/// Every outline is built analytically. `CGPath.copy(strokingWithWidth:)` is
/// deliberately not used: it flattens curves into large numbers of short line
/// segments, producing paths that are enormous, unstable, and impossible to
/// reason about downstream.
///
/// - Note: Joins are always round. Where a centerline turns a corner -- a sharp
///   rounded rectangle, a polyline vertex -- the outer boundary is swept by a
///   disc of half the stroke width. `LineJoin.miter` and `.bevel` are recorded
///   on the primitive but not yet honoured here. Round is the default and is
///   what SF Symbols artwork overwhelmingly uses, so this is a gap rather than
///   a wrong answer; miter joins matter for hard-cornered marks.
public enum Outliner {

    /// Outlines a primitive's centerline at a given stroke width.
    ///
    /// Returns `nil` for primitives with no resolvable centerline: compounds
    /// reference other primitives by identity, and imported paths carry raw
    /// path data rather than semantic geometry.
    public static func outline(_ primitive: IconPrimitive,
                               width: Double) -> OutlinePath? {
        let stroke = primitive.attributes.stroke

        switch primitive {
        case .line(let line):
            return outlineSegment(from: line.start,
                                  to: line.end,
                                  width: width,
                                  cap: stroke.lineCap)

        case .circle(let circle):
            return outlineRing(center: circle.center,
                               radius: circle.radius,
                               width: width)

        case .arc(let arc):
            return outlineArc(arc, width: width, cap: stroke.lineCap)

        case .roundedRect(let rect):
            return outlineRoundedRect(bounds: rect.bounds,
                                      cornerRadius: rect.effectiveCornerRadius,
                                      width: width)

        case .capsule(let capsule):
            return outlineRoundedRect(bounds: capsule.bounds,
                                      cornerRadius: capsule.cornerRadius,
                                      width: width)

        case .polyline(let polyline):
            return outlinePolyline(points: polyline.points,
                                   isClosed: polyline.isClosed,
                                   width: width,
                                   cap: stroke.lineCap)

        case .symmetricPath(let path):
            return outlinePolyline(points: path.points + path.mirroredPoints,
                                   isClosed: true,
                                   width: width,
                                   cap: stroke.lineCap)

        case .compound, .importedPath:
            return nil
        }
    }

    // MARK: Line

    /// A stroked segment: two parallel edges joined by caps.
    ///
    /// Traversal runs down the right-hand side, round the far cap, back up the
    /// left, and round the near cap, which yields a counterclockwise contour.
    public static func outlineSegment(from start: IconPoint,
                                      to end: IconPoint,
                                      width: Double,
                                      cap: LineCap) -> OutlinePath {
        let radius = width / 2
        guard radius > .ulpOfOne else {
            return .empty
        }

        guard let direction = start.vector(to: end).normalized else {
            // A zero-length segment is a dot under a round cap, and nothing at
            // all under the others.
            return cap == .round
                ? outlineDisc(center: start, radius: radius)
                : .empty
        }

        let normal = direction.perpendicular
        let offset = normal.scaled(by: radius)

        // Square caps extend the segment by half a width before being capped
        // flat, which is exactly what a butt cap on a longer segment gives.
        let extension_ = cap == .square ? direction.scaled(by: radius) : .zero
        let nearEnd = start.offset(by: extension_.scaled(by: -1))
        let farEnd = end.offset(by: extension_)

        var segments: [OutlineSegment] = []

        let rightStart = nearEnd.offset(by: offset.scaled(by: -1))
        let rightEnd = farEnd.offset(by: offset.scaled(by: -1))
        let leftEnd = farEnd.offset(by: offset)
        let leftStart = nearEnd.offset(by: offset)

        segments.append(.line(from: rightStart, to: rightEnd))
        segments.append(contentsOf: capSegments(at: farEnd,
                                                radius: radius,
                                                from: rightEnd,
                                                to: leftEnd,
                                                normal: normal,
                                                cap: cap,
                                                isFarEnd: true))
        segments.append(.line(from: leftEnd, to: leftStart))
        segments.append(contentsOf: capSegments(at: nearEnd,
                                                radius: radius,
                                                from: leftStart,
                                                to: rightStart,
                                                normal: normal,
                                                cap: cap,
                                                isFarEnd: false))

        return OutlinePath(contours: [
            OutlineContour(segments: segments).oriented(counterclockwise: true)
        ])
    }

    private static func capSegments(at point: IconPoint,
                                    radius: Double,
                                    from: IconPoint,
                                    to: IconPoint,
                                    normal: IconVector,
                                    cap: LineCap,
                                    isFarEnd: Bool) -> [OutlineSegment] {
        switch cap {
        case .butt, .square:
            // Square caps already extended the endpoints, so both close flat.
            return [.line(from: from, to: to)]
        case .round:
            let negated = normal.scaled(by: -1)
            let startAngle = IconAngle(radians: isFarEnd
                ? atan2(negated.dy, negated.dx)
                : atan2(normal.dy, normal.dx))
            let endAngle = IconAngle(radians: isFarEnd
                ? atan2(normal.dy, normal.dx)
                : atan2(negated.dy, negated.dx))
            return [.arc(ArcSegment(center: point,
                                    radius: radius,
                                    startAngle: startAngle,
                                    endAngle: endAngle,
                                    isClockwise: false))]
        }
    }

    // MARK: Circle

    /// A stroked circle: an annulus, or a solid disc when the stroke swallows
    /// the hole.
    public static func outlineRing(center: IconPoint,
                                   radius: Double,
                                   width: Double) -> OutlinePath {
        let half = width / 2
        guard half > .ulpOfOne else {
            return .empty
        }

        let outer = radius + half
        let inner = radius - half

        guard inner > .ulpOfOne else {
            return outlineDisc(center: center, radius: outer)
        }

        return OutlinePath(contours: [
            circleContour(center: center, radius: outer, counterclockwise: true),
            circleContour(center: center, radius: inner, counterclockwise: false)
        ])
    }

    public static func outlineDisc(center: IconPoint, radius: Double) -> OutlinePath {
        guard radius > .ulpOfOne else {
            return .empty
        }
        return OutlinePath(contours: [
            circleContour(center: center, radius: radius, counterclockwise: true)
        ])
    }

    /// A full circle as a single closed arc.
    private static func circleContour(center: IconPoint,
                                      radius: Double,
                                      counterclockwise: Bool) -> OutlineContour {
        OutlineContour(segments: [
            .arc(ArcSegment(center: center,
                            radius: radius,
                            startAngle: .zero,
                            endAngle: .zero,
                            isClockwise: !counterclockwise))
        ])
    }

    // MARK: Arc

    /// A stroked arc: an outer arc, a cap, an inner arc back, and a cap.
    public static func outlineArc(_ arc: ArcPrimitive,
                                  width: Double,
                                  cap: LineCap) -> OutlinePath {
        let half = width / 2
        guard half > .ulpOfOne, arc.radius > .ulpOfOne else {
            return .empty
        }

        // A full circle has no ends to cap, so it is a plain ring.
        let turn = 2 * Double.pi
        if abs(arc.sweep - turn) < 1e-9 {
            return outlineRing(center: arc.center, radius: arc.radius, width: width)
        }

        let outerRadius = arc.radius + half
        let innerRadius = max(0, arc.radius - half)

        let outer = ArcSegment(center: arc.center,
                               radius: outerRadius,
                               startAngle: arc.startAngle,
                               endAngle: arc.endAngle,
                               isClockwise: arc.isClockwise)
        let inner = ArcSegment(center: arc.center,
                               radius: innerRadius,
                               startAngle: arc.startAngle,
                               endAngle: arc.endAngle,
                               isClockwise: arc.isClockwise)

        var segments: [OutlineSegment] = [.arc(outer)]

        // Cap across the far end, from the outer edge to the inner edge.
        segments.append(contentsOf: endCap(at: arc.point(atAngle: arc.endAngle),
                                           from: outer.endPoint,
                                           to: inner.endPoint,
                                           radius: half,
                                           cap: cap,
                                           innerRadius: innerRadius))

        segments.append(.arc(inner.reversed))

        segments.append(contentsOf: endCap(at: arc.point(atAngle: arc.startAngle),
                                           from: inner.startPoint,
                                           to: outer.startPoint,
                                           radius: half,
                                           cap: cap,
                                           innerRadius: innerRadius))

        return OutlinePath(contours: [
            OutlineContour(segments: segments).oriented(counterclockwise: true)
        ])
    }

    private static func endCap(at center: IconPoint,
                               from: IconPoint,
                               to: IconPoint,
                               radius: Double,
                               cap: LineCap,
                               innerRadius: Double) -> [OutlineSegment] {
        // When the stroke has swallowed the inner radius the two edges meet at
        // a point, and there is no cap to draw.
        guard from.distance(to: to) > 1e-12 else {
            return []
        }

        switch cap {
        case .butt, .square:
            return [.line(from: from, to: to)]
        case .round:
            let toStart = center.vector(to: from)
            let toEnd = center.vector(to: to)
            return [.arc(ArcSegment(
                center: center,
                radius: radius,
                startAngle: IconAngle(radians: atan2(toStart.dy, toStart.dx)),
                endAngle: IconAngle(radians: atan2(toEnd.dy, toEnd.dx)),
                isClockwise: false
            ))]
        }
    }

    // MARK: Rounded rectangle and capsule

    /// A stroked rounded rectangle: two nested rounded rectangles.
    public static func outlineRoundedRect(bounds: IconRect,
                                          cornerRadius: Double,
                                          width: Double) -> OutlinePath {
        let half = width / 2
        guard half > .ulpOfOne else {
            return .empty
        }

        let outerBounds = bounds.inset(by: -half)
        let outer = roundedRectContour(bounds: outerBounds,
                                       cornerRadius: cornerRadius + half,
                                       counterclockwise: true)

        // Once the stroke is thicker than the shape, the hole is gone and the
        // result is a solid rounded rectangle.
        let innerBounds = bounds.inset(by: half)
        guard innerBounds.size.width > .ulpOfOne,
              innerBounds.size.height > .ulpOfOne else {
            return OutlinePath(contours: [outer])
        }

        let inner = roundedRectContour(bounds: innerBounds,
                                       cornerRadius: max(0, cornerRadius - half),
                                       counterclockwise: false)

        return OutlinePath(contours: [outer, inner])
    }

    /// A rounded rectangle as four lines and four quarter arcs.
    ///
    /// Corners are true circular arcs rather than the `continuous` squircle
    /// style used for on-screen chrome: circular corners keep every
    /// intersection analytic, and match how SF Symbols geometry is built.
    private static func roundedRectContour(bounds: IconRect,
                                           cornerRadius: Double,
                                           counterclockwise: Bool) -> OutlineContour {
        let radius = max(0, min(cornerRadius,
                                min(bounds.size.width, bounds.size.height) / 2))

        guard radius > .ulpOfOne else {
            let corners = [
                IconPoint(x: bounds.minX, y: bounds.minY),
                IconPoint(x: bounds.maxX, y: bounds.minY),
                IconPoint(x: bounds.maxX, y: bounds.maxY),
                IconPoint(x: bounds.minX, y: bounds.maxY)
            ]
            let segments = corners.indices.map { index in
                OutlineSegment.line(from: corners[index],
                                    to: corners[(index + 1) % corners.count])
            }
            return OutlineContour(segments: segments)
                .oriented(counterclockwise: counterclockwise)
        }

        // Counterclockwise from the bottom edge, rounding each corner in turn.
        let left = bounds.minX, right = bounds.maxX
        let bottom = bounds.minY, top = bounds.maxY

        let segments: [OutlineSegment] = [
            .line(from: IconPoint(x: left + radius, y: bottom),
                  to: IconPoint(x: right - radius, y: bottom)),
            .arc(ArcSegment(center: IconPoint(x: right - radius, y: bottom + radius),
                            radius: radius,
                            startAngle: IconAngle(degrees: 270),
                            endAngle: IconAngle(degrees: 360))),
            .line(from: IconPoint(x: right, y: bottom + radius),
                  to: IconPoint(x: right, y: top - radius)),
            .arc(ArcSegment(center: IconPoint(x: right - radius, y: top - radius),
                            radius: radius,
                            startAngle: IconAngle(degrees: 0),
                            endAngle: IconAngle(degrees: 90))),
            .line(from: IconPoint(x: right - radius, y: top),
                  to: IconPoint(x: left + radius, y: top)),
            .arc(ArcSegment(center: IconPoint(x: left + radius, y: top - radius),
                            radius: radius,
                            startAngle: IconAngle(degrees: 90),
                            endAngle: IconAngle(degrees: 180))),
            .line(from: IconPoint(x: left, y: top - radius),
                  to: IconPoint(x: left, y: bottom + radius)),
            .arc(ArcSegment(center: IconPoint(x: left + radius, y: bottom + radius),
                            radius: radius,
                            startAngle: IconAngle(degrees: 180),
                            endAngle: IconAngle(degrees: 270)))
        ]

        return OutlineContour(segments: segments)
            .oriented(counterclockwise: counterclockwise)
    }

    // MARK: Polyline

    /// A stroked chain of segments.
    ///
    /// Each segment is outlined independently and the pieces are unioned by the
    /// boolean solver, with a disc at every interior vertex to fill the join.
    /// Building one continuous offset chain instead would need miter and bevel
    /// handling for every corner and still fail on self-intersecting chains;
    /// letting the solver do the work keeps this correct for any input.
    public static func outlinePolyline(points: [IconPoint],
                                       isClosed: Bool,
                                       width: Double,
                                       cap: LineCap) -> OutlinePath {
        let radius = width / 2
        guard radius > .ulpOfOne, points.count > 1 else {
            if let single = points.first, points.count == 1, cap == .round {
                return outlineDisc(center: single, radius: radius)
            }
            return .empty
        }

        var contours: [OutlineContour] = []

        var pairs: [(IconPoint, IconPoint)] = []
        for index in 0..<(points.count - 1) {
            pairs.append((points[index], points[index + 1]))
        }
        if isClosed, let first = points.first, let last = points.last {
            pairs.append((last, first))
        }

        for (start, end) in pairs {
            contours.append(contentsOf:
                outlineSegment(from: start, to: end, width: width, cap: cap).contours)
        }

        // Discs at interior vertices so the joins are filled. Round joins are
        // exactly this; other join styles differ only in the small region
        // outside the disc.
        let jointIndices = isClosed
            ? Array(points.indices)
            : Array(points.indices.dropFirst().dropLast())

        for index in jointIndices {
            contours.append(contentsOf:
                outlineDisc(center: points[index], radius: radius).contours)
        }

        return OutlinePath(contours: contours)
    }
}
