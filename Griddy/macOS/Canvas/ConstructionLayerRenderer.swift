//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyGeometry
import GriddyDocument

/// Draws the construction layer: grid, margins, baseline, and key shapes.
/// See spec 8.3.
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

        // The margins, key shapes and centre guides all hang off the symbol
        // centre, so the resolved margins are computed once and shared. The
        // outline resolution inside is the expensive part; do it only when
        // something needs it.
        let needsMargins: GuideSet = [.keyShapes, .margins, .centerLines, .diagonals]
        let resolved = guides.isDisjoint(with: needsMargins)
            ? nil : resolvedMargins()
        let centerX = resolved.map { $0.originX + $0.advance / 2 }

        if guides.contains(.keyShapes) {
            drawKeyShapes(in: &context, centerX: centerX ?? capHeightBox.center.x)
        }

        if guides.contains(.diagonals), let centerX {
            drawDiagonals(in: &context, centerX: centerX)
        }

        if guides.contains(.centerLines), let centerX {
            drawCenterLines(in: &context, centerX: centerX)
        }

        if guides.contains(.baseline) {
            drawBaselineAndCapline(in: &context)
        }

        if guides.contains(.margins), let resolved {
            drawMargins(in: &context, resolved: resolved)
        }
    }

    /// The symbol's horizontal metrics for the active weight, computed once per
    /// draw. The centre between its margins is where the key shapes and the
    /// centre guides sit — the point the artwork is meant to balance around.
    private func resolvedMargins() -> ResolvedMargins {
        ResolvedMargins.resolve(
            outline: document.resolvedOutline(weight: weight),
            weight: weight,
            margins: document.margins,
            coordinateSystem: document.coordinateSystem)
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

    /// Draws the key shapes centred on the symbol centre.
    ///
    /// Their stored bounds are centred on the cap-height box, which is the
    /// *template's* advance centre and no longer where the artwork sits once
    /// the margins move. Re-centring them on the live symbol centre is what
    /// makes them a usable target rather than a shape stranded to one side.
    private func drawKeyShapes(in context: inout GraphicsContext, centerX: Double) {
        let emphasised = document.keyShapes.shape(for: document.metadata.designIntent)

        for keyShape in document.keyShapes.all where keyShape.isVisible {
            let isEmphasised = keyShape.id == emphasised?.id
            let color: Color = isEmphasised ? .keyShapeEmphasised : .keyShape
            let centred = keyShape.bounds.offsetBy(
                dx: centerX - keyShape.bounds.center.x, dy: 0)
            let path = path(for: keyShape, bounds: centred)

            context.stroke(path,
                           with: .color(color),
                           style: StrokeStyle(lineWidth: isEmphasised ? 1.25 : 0.75,
                                              dash: isEmphasised ? [] : [3, 3]))
        }
    }

    private func path(for keyShape: KeyShape, bounds: IconRect) -> Path {
        let rect = transform.rect(bounds)
        return switch keyShape.kind {
        case .circle:
            Path(ellipseIn: rect)
        case .square, .horizontalRectangle, .verticalRectangle:
            Path(roundedRect: rect, cornerRadius: transform.length(0.5))
        case .customPath:
            Path(rect)
        }
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
    private func drawMargins(in context: inout GraphicsContext,
                             resolved: ResolvedMargins) {
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

    /// A vertical and a horizontal line through the symbol centre.
    ///
    /// The centre is the midpoint between the margins horizontally and the
    /// cap-height centre vertically — the point a symmetric symbol balances
    /// around. Both lines span the full design area so the centre reads at a
    /// glance.
    private func drawCenterLines(in context: inout GraphicsContext, centerX: Double) {
        let centerY = capHeightBox.center.y
        var path = Path()

        path.move(to: transform.point(IconPoint(x: centerX, y: designArea.minY)))
        path.addLine(to: transform.point(IconPoint(x: centerX, y: designArea.maxY)))

        path.move(to: transform.point(IconPoint(x: designArea.minX, y: centerY)))
        path.addLine(to: transform.point(IconPoint(x: designArea.maxX, y: centerY)))

        context.stroke(path,
                       with: .color(.centerLine),
                       style: StrokeStyle(lineWidth: 0.75, dash: [4, 3]))
    }

    /// Two diagonals crossing at the symbol centre.
    ///
    /// Drawn corner to corner of the margin box, which spans the design area
    /// vertically, so they cross exactly at the centre the centre lines mark.
    private func drawDiagonals(in context: inout GraphicsContext, centerX: Double) {
        let half = capHeightBox.size.height  // reach past the box for a clear X
        let top = designArea.maxY
        let bottom = designArea.minY
        let left = centerX - half
        let right = centerX + half

        var path = Path()
        path.move(to: transform.point(IconPoint(x: left, y: bottom)))
        path.addLine(to: transform.point(IconPoint(x: right, y: top)))
        path.move(to: transform.point(IconPoint(x: left, y: top)))
        path.addLine(to: transform.point(IconPoint(x: right, y: bottom)))

        context.stroke(path,
                       with: .color(.centerLine),
                       style: StrokeStyle(lineWidth: 0.75, dash: [4, 3]))
    }
}

// MARK: - Construction layer palette

private extension Color {

    static let canvasFill = Color(nsColor: .textBackgroundColor)
    static let marginEdge = Color.orange.opacity(0.55)
    static let gridPrimary = Color.secondary.opacity(0.28)
    static let gridSecondary = Color.secondary.opacity(0.12)
    static let keyShape = Color.secondary.opacity(0.35)
    static let keyShapeEmphasised = Color.accentColor.opacity(0.65)
    static let baseline = Color.blue.opacity(0.45)
    static let centerLine = Color.purple.opacity(0.5)
}
