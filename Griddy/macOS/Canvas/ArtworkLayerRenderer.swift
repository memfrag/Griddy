//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyGeometry
import GriddyDocument

/// Draws the artwork layer: primitives, the in-flight drag preview, and
/// selection affordances. See spec 8.3.
struct ArtworkLayerRenderer {

    let document: SymbolDocument
    let editor: CanvasEditor
    let transform: CanvasTransform

    func draw(in context: inout GraphicsContext) {
        for primitive in document.primitivesInDrawOrder
        where primitive.attributes.isVisible {
            drawFill(primitive, in: &context)
        }

        drawDragPreview(in: &context)
        drawSelection(in: &context)
        drawMarquee(in: &context)
    }

    // MARK: Artwork

    /// Strokes the centerline at the resolved width.
    ///
    /// This approximates what export will produce. It is not outlining: there
    /// is no analytic outline and no boolean resolution here, so overlapping
    /// primitives simply paint over each other. Milestone 3 replaces this for
    /// export purposes. See spec 10.5.
    private func drawFill(_ primitive: IconPrimitive,
                          in context: inout GraphicsContext) {
        let path = PrimitivePath.path(for: primitive, transform: transform)
        guard !path.isEmpty else {
            return
        }

        let width = document.strokeWidth(for: primitive, weight: editor.activeWeight)
        let stroke = primitive.attributes.stroke

        context.stroke(
            path,
            with: .color(.artwork),
            style: StrokeStyle(
                lineWidth: max(1, transform.length(width)),
                lineCap: stroke.lineCap.cgLineCap,
                lineJoin: stroke.lineJoin.cgLineJoin,
                miterLimit: stroke.miterLimit
            )
        )
    }

    // MARK: Drag preview

    private func drawDragPreview(in context: inout GraphicsContext) {
        guard let preview = editor.drag?.previewPrimitive else {
            return
        }
        let path = PrimitivePath.path(for: preview, transform: transform)
        guard !path.isEmpty else {
            return
        }

        let width = document.strokeWidth(for: preview, weight: editor.activeWeight)
        context.stroke(path,
                       with: .color(.artworkPreview),
                       style: StrokeStyle(lineWidth: max(1, transform.length(width)),
                                          lineCap: .round,
                                          lineJoin: .round))
    }

    // MARK: Selection

    private func drawSelection(in context: inout GraphicsContext) {
        for primitive in document.primitivesInDrawOrder
        where editor.selection.contains(primitive.id) {
            let path = PrimitivePath.path(for: primitive, transform: transform)
            if !path.isEmpty {
                context.stroke(path,
                               with: .color(.selection),
                               style: StrokeStyle(lineWidth: 1.5))
            }
            drawHandles(for: primitive, in: &context)
        }
    }

    /// Draws the anchor points a designer would grab.
    ///
    /// Handles are semantic: a circle shows its centre and its extent, an arc
    /// shows its endpoints. Milestone 4 makes them draggable.
    private func drawHandles(for primitive: IconPrimitive,
                             in context: inout GraphicsContext) {
        for point in handlePoints(for: primitive) {
            let center = transform.point(point)
            let size: CGFloat = 5
            let rect = CGRect(x: center.x - size / 2,
                              y: center.y - size / 2,
                              width: size,
                              height: size)
            context.fill(Path(rect), with: .color(.handleFill))
            context.stroke(Path(rect), with: .color(.selection), lineWidth: 1)
        }
    }

    private func handlePoints(for primitive: IconPrimitive) -> [IconPoint] {
        switch primitive {
        case .line(let line):
            [line.start, line.end]
        case .circle(let circle):
            [circle.center,
             IconPoint(x: circle.center.x + circle.radius, y: circle.center.y)]
        case .arc(let arc):
            [arc.center, arc.startPoint, arc.endPoint]
        case .roundedRect(let rect):
            corners(of: rect.bounds)
        case .capsule(let capsule):
            corners(of: capsule.bounds)
        case .polyline(let polyline):
            polyline.points
        case .symmetricPath(let path):
            path.points
        case .compound, .importedPath:
            PrimitiveGeometry.bounds(of: primitive).map(corners) ?? []
        }
    }

    private func corners(of rect: IconRect) -> [IconPoint] {
        [IconPoint(x: rect.minX, y: rect.minY),
         IconPoint(x: rect.maxX, y: rect.minY),
         IconPoint(x: rect.maxX, y: rect.maxY),
         IconPoint(x: rect.minX, y: rect.maxY)]
    }

    // MARK: Marquee

    private func drawMarquee(in context: inout GraphicsContext) {
        guard case .marquee = editor.drag, let drag = editor.drag else {
            return
        }
        let rect = transform.rect(drag.rect)
        context.fill(Path(rect), with: .color(.selection.opacity(0.1)))
        context.stroke(Path(rect),
                       with: .color(.selection),
                       style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
    }
}

// MARK: - Palette

private extension Color {
    static let artwork = Color.primary
    static let artworkPreview = Color.accentColor.opacity(0.75)
    static let selection = Color.accentColor
    static let handleFill = Color(nsColor: .windowBackgroundColor)
}

// MARK: - Stroke style bridging

private extension GriddyGeometry.LineCap {
    var cgLineCap: CGLineCap {
        switch self {
        case .butt: .butt
        case .round: .round
        case .square: .square
        }
    }
}

private extension GriddyGeometry.LineJoin {
    var cgLineJoin: CGLineJoin {
        switch self {
        case .miter: .miter
        case .round: .round
        case .bevel: .bevel
        }
    }
}
