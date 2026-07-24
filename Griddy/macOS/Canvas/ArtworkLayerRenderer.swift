//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyGeometry
import GriddyDocument
import GriddySymbols

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
        drawPathPreview(in: &context)
        drawSelection(in: &context)
        drawMarquee(in: &context)
    }

    /// The in-progress pen path: placed points joined by segments, a rubber-band
    /// segment to the cursor, and a dot on each point. The first dot is drawn
    /// larger so it is obvious that clicking it closes the path.
    private func drawPathPreview(in context: inout GraphicsContext) {
        let points = editor.pathPoints
        guard editor.tool.isPathTool, !points.isEmpty else {
            return
        }

        var line = Path()
        line.move(to: transform.point(points[0]))
        for point in points.dropFirst() {
            line.addLine(to: transform.point(point))
        }
        if let cursor = editor.pathCursor {
            line.addLine(to: transform.point(cursor))
        }
        context.stroke(line, with: .color(.artworkPreview),
                       style: StrokeStyle(lineWidth: 1.5))

        for (index, point) in points.enumerated() {
            let center = transform.point(point)
            let size: CGFloat = index == 0 ? 8 : 5
            let rect = CGRect(x: center.x - size / 2, y: center.y - size / 2,
                              width: size, height: size)
            context.fill(Path(ellipseIn: rect), with: .color(.artworkPreview))
        }
    }

    // MARK: Artwork

    /// Fills the primitive's analytic outline.
    ///
    /// This is the real outlining pipeline, the same geometry export uses --
    /// not a stroked approximation. Boolean resolution is not applied here:
    /// overlapping primitives are filled independently, which for monochrome
    /// artwork in a single colour is visually identical to their union. The
    /// difference shows up in the exported path structure and in subtract
    /// operations, which is where the solver matters. See spec 10.5.
    private func drawFill(_ primitive: IconPrimitive,
                          in context: inout GraphicsContext) {
        // Imported artwork is already a filled outline, not a centerline, so it
        // is drawn as it arrived rather than being run through the outliner.
        // Nothing about it is reinterpreted. See spec 14.3.
        if case .importedPath(let imported) = primitive {
            drawImported(imported, in: &context)
            return
        }

        let width = document.strokeWidth(for: primitive, weight: editor.activeWeight)

        guard let outline = Outliner.outline(primitive, width: width),
              !outline.isEmpty else {
            return
        }

        let path = outline.cgPath(transform: transform)
        guard !path.isEmpty else {
            return
        }

        // Non-zero winding, because the outliner orients outer boundaries
        // counterclockwise and holes clockwise. Even-odd would fill a ring's
        // hole whenever another contour happened to overlap it.
        context.fill(path, with: .color(.artwork), style: FillStyle(eoFill: false))
    }

    /// Fills imported path data exactly as it was imported.
    private func drawImported(_ imported: ImportedPathPrimitive,
                              in context: inout GraphicsContext) {
        guard let commands = try? SVGPathData.parse(imported.pathData) else {
            return
        }

        var path = Path()
        for command in commands {
            switch command {
            case .move(let to):
                path.move(to: transform.point(to))
            case .line(let to):
                path.addLine(to: transform.point(to))
            case .cubic(let control1, let control2, let to):
                path.addCurve(to: transform.point(to),
                              control1: transform.point(control1),
                              control2: transform.point(control2))
            case .close:
                path.closeSubpath()
            }
        }

        guard !path.isEmpty else {
            return
        }
        // Non-zero, matching how the source template's own fill-rule reads, so
        // counters stay open.
        context.fill(path, with: .color(.artwork), style: FillStyle(eoFill: false))
    }

    // MARK: Drag preview

    private func drawDragPreview(in context: inout GraphicsContext) {
        guard let preview = editor.drag?.previewPrimitive else {
            return
        }
        let width = document.strokeWidth(for: preview, weight: editor.activeWeight)
        guard let outline = Outliner.outline(preview, width: width) else {
            return
        }

        let path = outline.cgPath(transform: transform)
        guard !path.isEmpty else {
            return
        }
        context.fill(path,
                     with: .color(.artworkPreview),
                     style: FillStyle(eoFill: false))
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
        // The same semantic handles the gesture layer drags, so what is drawn
        // and what is grabbable can never drift apart. A corner-radius handle is
        // round, and a smooth-curve vertex is round while a sharp one is square,
        // so a glance shows which points are corners.
        for handle in primitive.handles {
            let center = transform.point(handle.position)
            let size: CGFloat = 5
            let rect = CGRect(x: center.x - size / 2,
                              y: center.y - size / 2,
                              width: size,
                              height: size)
            let shape = isRoundHandle(handle.handle, of: primitive)
                ? Path(ellipseIn: rect) : Path(rect)
            // The point being edited is filled in the accent colour so it is
            // clear which one the inspector's tension slider acts on.
            let isSelectedVertex: Bool = {
                if case .vertex(let index) = handle.handle {
                    return editor.selectedVertex == index
                }
                return false
            }()
            context.fill(shape, with: .color(isSelectedVertex
                                             ? .selectedHandleFill : .handleFill))
            context.stroke(shape, with: .color(.selection), lineWidth: 1)
        }

        drawFreeHandleArms(for: primitive, in: &context)

        // Compounds and imported paths have no reshape handles, but their
        // extent is still worth marking while selected.
        if primitive.handles.isEmpty,
           let bounds = document.bounds(of: primitive) {
            for point in corners(of: bounds) {
                let center = transform.point(point)
                let rect = CGRect(x: center.x - 2.5, y: center.y - 2.5,
                                  width: 5, height: 5)
                context.stroke(Path(rect), with: .color(.selection), lineWidth: 1)
            }
        }
    }

    /// Draws the two tangent arms of the selected free-mode curve point, so
    /// they can be grabbed and dragged. Only the selected point shows them, to
    /// keep the canvas legible. See spec 10.5.
    private func drawFreeHandleArms(for primitive: IconPrimitive,
                                    in context: inout GraphicsContext) {
        guard case .polyline(let polyline) = primitive,
              let index = editor.selectedVertex,
              let handle = polyline.handle(at: index),
              polyline.points.indices.contains(index) else {
            return
        }
        let anchor = polyline.points[index]

        for offset in [handle.outOffset, handle.inOffset] {
            let end = anchor.offset(by: offset)
            var arm = Path()
            arm.move(to: transform.point(anchor))
            arm.addLine(to: transform.point(end))
            context.stroke(arm, with: .color(.handleArm), lineWidth: 1)

            let center = transform.point(end)
            let rect = CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)
            context.fill(Path(ellipseIn: rect), with: .color(.selection))
        }
    }

    /// Whether a handle is drawn round: the corner-radius handle always, and a
    /// smooth-curve vertex when that point is rounded rather than a corner.
    private func isRoundHandle(_ handle: PrimitiveHandle,
                               of primitive: IconPrimitive) -> Bool {
        if handle == .cornerRadius {
            return true
        }
        if case .vertex(let index) = handle,
           case .polyline(let polyline) = primitive,
           polyline.isSmooth {
            return polyline.smoothness(at: index) > 0.5
        }
        return false
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
    static let selectedHandleFill = Color.accentColor
    static let handleArm = Color.accentColor.opacity(0.6)
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
