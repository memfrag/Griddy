//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyGeometry
import GriddyDocument

/// Draws the construction layer: grid, safe area, margins, baseline, key
/// shapes and symmetry axes. See spec 8.3.
struct ConstructionLayerRenderer {

    let document: SymbolDocument

    /// Which master the margins are drawn for. They are per-weight: a heavier
    /// master is a wider glyph and claims more room.
    let weight: SymbolWeight

    let transform: CanvasTransform

    /// The drawing surface: what the grid covers and the view fits to.
    private var designArea: IconRect {
        document.coordinateSystem.designArea
    }

    /// Baseline to capline. A reference to align against, not a boundary --
    /// artwork legitimately extends past it. See spec 9.1.
    private var capHeightBox: IconRect {
        document.coordinateSystem.capHeightBox
    }

    private var guides: GuideSet {
        document.grid.visibleGuides
    }

    func draw(in context: inout GraphicsContext) {
        drawCanvasFill(in: &context)

        if guides.contains(.secondaryGrid) {
            drawGrid(in: &context,
                     interval: document.grid.secondaryInterval,
                     color: .gridSecondary,
                     lineWidth: 0.5)
        }

        if guides.contains(.primaryGrid) {
            drawGrid(in: &context,
                     interval: document.grid.primaryInterval,
                     color: .gridPrimary,
                     lineWidth: 0.75)
        }

        if guides.contains(.keyShapes) {
            drawKeyShapes(in: &context)
        }

        if guides.contains(.safeArea) {
            drawSafeArea(in: &context)
        }

        if guides.contains(.baseline) {
            drawBaselineAndCapline(in: &context)
        }

        if guides.contains(.margins) {
            drawMargins(in: &context)
        }
    }

    // MARK: Pieces

    private func drawCanvasFill(in context: inout GraphicsContext) {
        context.fill(Path(transform.rect(designArea)), with: .color(.canvasFill))
    }

    private func drawGrid(in context: inout GraphicsContext,
                          interval: Double,
                          color: Color,
                          lineWidth: Double) {
        guard interval > .ulpOfOne else {
            return
        }

        // Skip drawing when lines would be closer together than a couple of
        // points on screen, which turns the grid into a solid block.
        guard transform.length(interval) >= 3 else {
            return
        }

        var path = Path()

        var x = designArea.minX
        while x <= designArea.maxX + .ulpOfOne {
            path.move(to: transform.point(IconPoint(x: x, y: designArea.minY)))
            path.addLine(to: transform.point(IconPoint(x: x, y: designArea.maxY)))
            x += interval
        }

        var y = designArea.minY
        while y <= designArea.maxY + .ulpOfOne {
            path.move(to: transform.point(IconPoint(x: designArea.minX, y: y)))
            path.addLine(to: transform.point(IconPoint(x: designArea.maxX, y: y)))
            y += interval
        }

        context.stroke(path, with: .color(color), lineWidth: lineWidth)
    }

    private func drawKeyShapes(in context: inout GraphicsContext) {
        let emphasised = document.keyShapes.shape(for: document.metadata.designIntent)

        for keyShape in document.keyShapes.all where keyShape.isVisible {
            let isEmphasised = keyShape.id == emphasised?.id
            let color: Color = isEmphasised ? .keyShapeEmphasised : .keyShape
            let path = path(for: keyShape)

            context.stroke(path,
                           with: .color(color),
                           style: StrokeStyle(lineWidth: isEmphasised ? 1.25 : 0.75,
                                              dash: isEmphasised ? [] : [3, 3]))
        }
    }

    private func path(for keyShape: KeyShape) -> Path {
        let rect = transform.rect(keyShape.bounds)
        return switch keyShape.kind {
        case .circle:
            Path(ellipseIn: rect)
        case .square, .horizontalRectangle, .verticalRectangle:
            Path(roundedRect: rect, cornerRadius: transform.length(0.5))
        case .customPath:
            Path(rect)
        }
    }

    private func drawSafeArea(in context: inout GraphicsContext) {
        let rect = transform.rect(document.grid.safeArea)
        context.stroke(Path(roundedRect: rect, cornerRadius: transform.length(1)),
                       with: .color(.safeArea),
                       style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
    }

    private func drawBaselineAndCapline(in context: inout GraphicsContext) {
        var path = Path()

        // The baseline is unit-space Y = 0 and the capline is Y = 16, by
        // definition of the coordinate system.
        for y in [capHeightBox.minY, capHeightBox.maxY] {
            path.move(to: transform.point(IconPoint(x: designArea.minX - 1, y: y)))
            path.addLine(to: transform.point(IconPoint(x: designArea.maxX + 1, y: y)))
        }

        context.stroke(path,
                       with: .color(.baseline),
                       style: StrokeStyle(lineWidth: 1, dash: [6, 3]))
    }

    /// The symbol's advance: glyph origin on the left, next glyph's origin on
    /// the right.
    ///
    /// Not a bound on artwork — a glyph may overhang its own side bearings.
    /// It is how much room the symbol claims in a line of text.
    ///
    /// This used to also stroke the cap-height box. Nothing was gained: the
    /// box's horizontal edges are the baseline and capline, already drawn above
    /// in blue, so the canvas carried two dashed strokes along the same two
    /// lines; and its vertical edges sat on the design area's own edges, which
    /// bound nothing.
    private func drawMargins(in context: inout GraphicsContext) {
        // Computed from this master's artwork, not copied from whatever the
        // source template carried — so the guide moves as the drawing does,
        // which is the whole point of an advance width. See spec 9.3.
        let resolved = ResolvedMargins.resolve(
            outline: document.resolvedOutline(weight: weight),
            weight: weight,
            margins: document.margins,
            coordinateSystem: document.coordinateSystem)

        // Placed against the artwork where it actually sits on the canvas.
        // Export normalises the drawing onto the glyph origin; drawing these at
        // 0 and `advance` would put them somewhere the artwork isn't.
        let designArea = self.designArea
        var edges = Path()
        for x in [resolved.originX, resolved.originX + resolved.advance] {
            edges.move(to: transform.point(IconPoint(x: x, y: designArea.minY)))
            edges.addLine(to: transform.point(IconPoint(x: x, y: designArea.maxY)))
        }
        context.stroke(edges, with: .color(.marginEdge), lineWidth: 1)
    }
}

// MARK: - Construction layer palette

private extension Color {

    static let canvasFill = Color(nsColor: .textBackgroundColor)
    static let marginEdge = Color.orange.opacity(0.55)
    static let gridPrimary = Color.secondary.opacity(0.28)
    static let gridSecondary = Color.secondary.opacity(0.12)
    static let safeArea = Color.green.opacity(0.7)
    static let keyShape = Color.secondary.opacity(0.35)
    static let keyShapeEmphasised = Color.accentColor.opacity(0.65)
    static let baseline = Color.blue.opacity(0.45)
}
