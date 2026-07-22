//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyGeometry
import GriddyConstraints
import GriddyDocument

/// The drawing canvas. See spec 8.3.
struct SymbolCanvasView: View {

    @ObservedObject var file: SymbolDocumentFile
    @Bindable var editor: CanvasEditor
    @Environment(\.undoManager) private var undoManager

    /// Document state captured when the current gesture began, so the whole
    /// gesture collapses into one undo step. See spec 16.4.
    @State private var gestureSnapshot: SymbolDocument?

    private var document: SymbolDocument {
        file.document
    }

    var body: some View {
        // No GeometryReader and no explicit frame. Canvas already reports its
        // size to the draw closure, and a hard .frame() would make the detail
        // column non-compressible, which clips the sidebar when the inspector
        // is open.
        Canvas { context, size in
            let transform = makeTransform(for: size)
            var context = context

            ConstructionLayerRenderer(document: document,
                                      weight: editor.activeWeight,
                                      transform: transform)
                .draw(in: &context)
            ArtworkLayerRenderer(document: document,
                                 editor: editor,
                                 transform: transform)
                .draw(in: &context)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .background(PaneBackground())
        .onChange(of: document.primitives.count) {
            editor.pruneSelection(against: document)
        }
    }

    // MARK: Transform

    /// The canvas size is not known outside the draw closure, so gestures use
    /// the size recorded on the last draw.
    @State private var lastCanvasSize: CGSize = CGSize(width: 1, height: 1)

    private func makeTransform(for size: CGSize) -> CanvasTransform {
        if size != lastCanvasSize {
            // Recorded during draw for the gesture handlers to reuse. Deferred
            // so it does not mutate state during view update.
            Task { @MainActor in lastCanvasSize = size }
        }
        return CanvasTransform(fitting: document.visibleBounds,
                               in: size)
    }

    private var transform: CanvasTransform {
        CanvasTransform(fitting: document.visibleBounds,
                        in: lastCanvasSize)
    }

    /// Hit tolerance in units, derived from a constant on-screen target so it
    /// stays usable at any zoom.
    private var hitTolerance: Double {
        let scale = transform.scale
        guard scale > .ulpOfOne else {
            return 0.25
        }
        return CanvasEditor.hitToleranceInPoints / scale
    }

    // MARK: Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let point = snapped(transform.iconPoint(value.location))
                if editor.drag == nil {
                    beginDrag(at: snapped(transform.iconPoint(value.startLocation)))
                }
                updateDrag(to: point)
            }
            .onEnded { value in
                endDrag(at: snapped(transform.iconPoint(value.location)))
            }
    }

    private func snapped(_ point: IconPoint) -> IconPoint {
        document.grid.snapped(point)
    }

    /// The freedom the whole selection retains, as the intersection of each
    /// member's own restriction.
    ///
    /// Dragging a mixed selection can only move in directions every member is
    /// free to move in, or the constrained ones would be dragged out of
    /// compliance while the others kept up.
    private func dragRestriction() -> DragRestriction {
        editor.selection.reduce(DragRestriction.free) { result, id in
            result.intersected(with: document.dragRestriction(for: id))
        }
    }

    private func beginDrag(at point: IconPoint) {
        gestureSnapshot = file.beginGesture()

        if editor.tool.isDrawingTool {
            editor.drag = .creating(tool: editor.tool, start: point, current: point)
            return
        }

        let hit = HitTesting.topmost(in: document.primitivesInDrawOrder,
                                     at: point,
                                     tolerance: hitTolerance)

        if let hit, document.isEditable(hit.id) {
            if !editor.selection.contains(hit.id) {
                editor.selectOnly(hit.id)
            }
            editor.drag = .moving(start: point, current: point)
        } else {
            editor.selection = []
            editor.drag = .marquee(start: point, current: point)
        }
    }

    private func updateDrag(to point: IconPoint) {
        guard let drag = editor.drag else {
            return
        }

        if case .moving = drag {
            // Apply the delta since the last update, without touching the undo
            // stack; the whole gesture becomes one step when it ends.
            var delta = IconVector(dx: point.x - drag.current.x,
                                   dy: point.y - drag.current.y)

            // Constraints restrict the *input* of the edit rather than being
            // checked afterwards, which is what makes them invariants: geometry
            // simply cannot be dragged out of compliance. See spec 11.2.
            delta = dragRestriction().apply(to: delta)

            if delta.length > .ulpOfOne {
                file.updateWithoutUndo { document in
                    document.translatePrimitives(withIDs: editor.selection, by: delta)
                    // Whatever depends on the moved geometry follows it. The
                    // held primitives are pinned so the drag is not undone by
                    // the constraints that rely on it.
                    document.resolveConstraints(pinned: editor.selection)
                }
            }
        }

        editor.drag = drag.withCurrent(point)
    }

    private func endDrag(at point: IconPoint) {
        defer {
            editor.drag = nil
            gestureSnapshot = nil
        }

        guard let drag = editor.drag, let snapshot = gestureSnapshot else {
            return
        }

        switch drag {
        case .creating(let tool, let start, _):
            guard let primitive = tool.makePrimitive(from: start, to: point) else {
                return
            }
            file.updateWithoutUndo { document in
                document.addPrimitive(primitive)
            }
            editor.selectOnly(primitive.id)
            file.commitGesture("Add \(tool.label)",
                               from: snapshot,
                               undoManager: undoManager)

        case .moving:
            file.commitGesture(moveActionName(),
                               from: snapshot,
                               undoManager: undoManager)

        case .marquee:
            let picked = HitTesting.primitives(in: document.primitivesInDrawOrder,
                                               intersecting: drag.rect)
            editor.selection = Set(picked.map(\.id))
        }
    }

    private func moveActionName() -> String {
        guard editor.selection.count == 1,
              let id = editor.selection.first,
              let primitive = document.primitive(withID: id) else {
            return "Move \(editor.selection.count) Primitives"
        }
        return "Move \(primitive.kindName)"
    }
}
