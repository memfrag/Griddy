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
    @Environment(AppSettings.self) private var settings

    /// Document state captured when the current gesture began, so the whole
    /// gesture collapses into one undo step. See spec 16.4.
    @State private var gestureSnapshot: SymbolDocument?

    /// Whether the canvas holds keyboard focus, which `.onKeyPress` requires.
    /// A Canvas with a drag gesture does not reliably take focus on click, so
    /// it is claimed explicitly on appearance and on the first drag.
    @FocusState private var isFocused: Bool

    /// Whether the pointer is over the canvas, for the crosshair cursor.
    @State private var isHovering = false

    /// The selection a shift-marquee adds to, captured when the drag begins so
    /// it is not disturbed while the rubber band sweeps.
    @State private var additiveMarquee = false
    @State private var marqueeBase: Set<PrimitiveID> = []

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
        // A crosshair while a drawing tool is active, so it is obvious the next
        // click will draw rather than select. Pushed onto the cursor stack
        // rather than `set()`, which AppKit resets on the next mouse move; a
        // pushed cursor persists until popped. See spec 8.3.
        .onHover { hovering in
            isHovering = hovering
            syncCrosshair()
        }
        // The pen's rubber-band segment follows the pointer between clicks.
        .onContinuousHover { phase in
            switch phase {
            case .active(let location) where editor.tool.isPathTool:
                editor.pathCursor = snapped(transform.iconPoint(location))
            case .active, .ended:
                editor.pathCursor = nil
            }
        }
        .onChange(of: editor.tool) { _, _ in
            syncCrosshair()
            editor.clearPath()  // switching tools abandons an unfinished path
        }
        .onDisappear { popCrosshairIfNeeded() }
        // Focusable so the canvas receives key events. Space temporarily or
        // permanently switches to Select while drawing; see spec 8.3.
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(.space, phases: [.down, .up, .repeat], action: handleSpace)
        // Return finishes an open path; Escape abandons it.
        .onKeyPress(.return) {
            guard editor.tool.isPathTool, editor.pathPoints.count >= 2 else {
                return .ignored
            }
            finishPath(closed: false)
            return .handled
        }
        .onKeyPress(.escape) {
            guard editor.tool.isPathTool, !editor.pathPoints.isEmpty else {
                return .ignored
            }
            editor.clearPath()
            return .handled
        }
        .onAppear { isFocused = true }
        .onChange(of: document.primitives.count) {
            editor.pruneSelection(against: document)
        }
    }

    /// Switches to the Select tool on space, per the user's preference.
    ///
    /// Momentary: hold to select, release to return to the drawing tool.
    /// Toggle: tap to switch and stay. Either way it does nothing unless a
    /// drawing tool is active, and never interrupts a drag in progress.
    ///
    /// Every space event is reported handled, including the repeats a held key
    /// generates. Returning `.ignored` would let the key propagate up a
    /// responder chain that has no other use for space, and an unhandled key
    /// event rings the system bell — which is what a held space did.
    private func handleSpace(_ press: KeyPress) -> KeyPress.Result {
        switch press.phase {
        case .down:
            // Act only on the first press. Repeats arrive as `.repeat` and,
            // even if one slips in as `.down`, the guard stops it re-saving
            // Select as the tool to restore.
            if editor.toolBeforeSpace == nil,
               editor.tool.isDrawingTool,
               editor.drag == nil {
                editor.toolBeforeSpace = editor.tool
                editor.tool = .select
            }
            return .handled

        case .up:
            if let previous = editor.toolBeforeSpace {
                // Momentary returns to the drawing tool; toggle keeps Select.
                // The saved tool is cleared either way so the next press starts
                // fresh.
                if settings.spaceToolBehavior == .momentary {
                    editor.tool = previous
                }
                editor.toolBeforeSpace = nil
            }
            return .handled

        default:
            // A repeat while the key is held: swallow it so it does not beep.
            return .handled
        }
    }

    // MARK: Cursor

    /// Pushes or pops the crosshair so it is shown exactly while the pointer is
    /// over the canvas and a drawing tool is active.
    ///
    /// A pushed cursor survives mouse movement, which a bare `set()` does not —
    /// AppKit restores the default on the next move unless a cursor rect or
    /// tracking area re-sets it, and neither plays nicely with the SwiftUI drag
    /// gesture. The `crosshairPushed` flag keeps every push matched to one pop.
    private func syncCrosshair() {
        let wantsCrosshair = isHovering && editor.tool.isDrawingTool
        if wantsCrosshair, !editor.crosshairPushed {
            NSCursor.crosshair.push()
            editor.crosshairPushed = true
        } else if !wantsCrosshair {
            popCrosshairIfNeeded()
        }
    }

    private func popCrosshairIfNeeded() {
        if editor.crosshairPushed {
            NSCursor.pop()
            editor.crosshairPushed = false
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

    /// A slightly tighter grab radius for handles than for shape bodies, so a
    /// click just inside a shape's edge moves it rather than snapping to a
    /// handle it was not quite on.
    private var handleTolerance: Double {
        let scale = transform.scale
        guard scale > .ulpOfOne else {
            return 0.2
        }
        return CanvasEditor.hitToleranceInPoints / scale
    }

    // MARK: Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if editor.drag == nil {
                    beginDrag(atRaw: transform.iconPoint(value.startLocation))
                }
                updateDrag(to: snapped(transform.iconPoint(value.location)))
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

    /// Begins a gesture.
    ///
    /// - Parameter raw: the cursor in unit space, *not* snapped to the grid.
    ///   Hit testing uses this raw point so a handle or shape can be grabbed
    ///   wherever it actually is; snapping applies to the drag's result, not to
    ///   deciding what was clicked. Snapping the click first made small targets
    ///   like a line's endpoints nearly ungrabbable, because the click rounded
    ///   to the nearest grid point before the handle test ran.
    private func beginDrag(atRaw raw: IconPoint) {
        // Interacting with the canvas takes keyboard focus back from the
        // sidebar or inspector, so space works after a click here.
        isFocused = true

        // A path tool builds from discrete clicks; nothing is committed until
        // the path finishes, so there is no gesture to snapshot and no shape to
        // preview during the click. The point is placed on release.
        if editor.tool.isPathTool {
            editor.drag = .inert
            return
        }

        gestureSnapshot = file.beginGesture()

        // Geometry starts on the grid; hit testing uses the raw point.
        let point = snapped(raw)

        if editor.tool.isDrawingTool {
            editor.drag = .creating(tool: editor.tool, start: point, current: point)
            return
        }

        // A handle of the current selection wins over hitting a shape body, so
        // grabbing the edge of a selected circle resizes it rather than
        // starting a move. Handles are only live for a single selection —
        // reshaping several primitives at once has no obvious meaning.
        if let grabbed = handleUnderCursor(at: raw) {
            // Option-clicking a smooth-curve vertex toggles it between a rounded
            // point and a sharp corner, rather than starting a reshape.
            if NSEvent.modifierFlags.contains(.option),
               case .vertex(let index) = grabbed.handle,
               isSmoothVertex(grabbed.id) {
                toggleCorner(grabbed.id, at: index)
                editor.drag = .inert
                return
            }
            editor.drag = .reshaping(primitiveID: grabbed.id,
                                     handle: grabbed.handle,
                                     start: point, current: point)
            return
        }

        // Roots only, and compound-aware: hit testing the flat list would find
        // a compound's children, which are still in the document but no longer
        // drawn, so clicking a combined shape would select an invisible operand.
        let hit = document.topmostPrimitive(at: raw, tolerance: hitTolerance)

        // Shift extends the selection rather than replacing it — click shapes
        // to add or remove them one at a time, or shift-drag a marquee to add
        // a group. The modifier is read from AppKit because a SwiftUI
        // DragGesture value does not carry it.
        let extending = NSEvent.modifierFlags.contains(.shift)

        if let hit, document.isEditable(hit.id) {
            if extending {
                // Toggle this shape's membership, leaving the rest alone, and
                // arm no move: a shift-click is a pure selection change, so a
                // stray drag afterwards must not nudge the group.
                if editor.selection.contains(hit.id) {
                    editor.selection.remove(hit.id)
                } else {
                    editor.selection.insert(hit.id)
                }
                editor.drag = .inert
            } else {
                if !editor.selection.contains(hit.id) {
                    editor.selectOnly(hit.id)
                }
                editor.drag = .moving(start: point, current: point)
            }
        } else {
            // Shift keeps the current selection so the marquee adds to it; a
            // plain click on empty space clears it.
            additiveMarquee = extending
            marqueeBase = extending ? editor.selection : []
            if !extending {
                editor.selection = []
            }
            editor.drag = .marquee(start: point, current: point)
        }
    }

    // MARK: Curve corners

    private func isSmoothVertex(_ id: PrimitiveID) -> Bool {
        if case .polyline(let polyline)? = document.primitive(withID: id) {
            return polyline.isSmooth
        }
        return false
    }

    /// Flips a smooth-curve point between rounded and sharp.
    private func toggleCorner(_ id: PrimitiveID, at index: Int) {
        file.perform("Toggle Corner", undoManager: undoManager) { document in
            guard case .polyline(var polyline)? = document.primitive(withID: id) else {
                return
            }
            let rounded = polyline.smoothness(at: index) > 0.5
            polyline.setSmoothness(rounded ? 0 : 1, at: index)
            document.replacePrimitive(.polyline(polyline))
        }
    }

    // MARK: Path tools (pen)

    /// Places a point, or closes the path if the click lands on its start.
    ///
    /// Closing needs at least three points; a two-point "closed" path is just a
    /// line doubled back on itself.
    private func addPathPoint(_ point: IconPoint) {
        if editor.pathPoints.count >= 3,
           let first = editor.pathPoints.first,
           first.distance(to: point) <= handleTolerance {
            finishPath(closed: true)
            return
        }
        editor.pathPoints.append(point)
    }

    /// Commits the collected points as one primitive, in a single undo step.
    ///
    /// The pen makes a polyline; its stroke defaults to round caps and joins,
    /// so an open path reads as a rounded stroke with no extra setup. A future
    /// curve tool will branch here to fit arcs instead.
    private func finishPath(closed: Bool) {
        defer { editor.clearPath() }
        guard editor.pathPoints.count >= 2 else {
            return
        }

        let smooth = editor.tool.makesSmoothPath
        let primitive = IconPrimitive.polyline(
            PolylinePrimitive(points: editor.pathPoints,
                              isClosed: closed, isSmooth: smooth))

        let name = smooth ? "Add Curve" : (closed ? "Add Closed Path" : "Add Path")
        let snapshot = file.beginGesture()
        file.updateWithoutUndo { document in
            document.addPrimitive(primitive)
        }
        editor.selectOnly(primitive.id)
        file.commitGesture(name, from: snapshot, undoManager: undoManager)
    }

    /// The handle of the single selected primitive nearest the cursor, if one
    /// is within grabbing distance.
    private func handleUnderCursor(at point: IconPoint)
    -> (id: PrimitiveID, handle: PrimitiveHandle)? {
        guard editor.selection.count == 1,
              let id = editor.selection.first,
              let primitive = document.primitive(withID: id),
              document.isEditable(id) else {
            return nil
        }

        let nearest = primitive.handles.min {
            $0.position.distance(to: point) < $1.position.distance(to: point)
        }
        guard let nearest,
              nearest.position.distance(to: point) <= handleTolerance else {
            return nil
        }
        return (id, nearest.handle)
    }

    private func updateDrag(to point: IconPoint) {
        guard let drag = editor.drag else {
            return
        }

        if case .reshaping(let id, let handle, _, _) = drag {
            // Reshaping writes the primitive directly to the snapped pointer, so
            // there is no delta to accumulate: the handle simply follows the
            // cursor. Off the undo stack until the gesture ends.
            file.updateWithoutUndo { document in
                guard let primitive = document.primitive(withID: id) else {
                    return
                }
                document.replacePrimitive(primitive.moving(handle, to: point))
                // A constrained sibling follows the reshaped primitive, which is
                // pinned so the drag is not undone by what depends on it.
                document.resolveConstraints(pinned: [id])
            }
            editor.drag = drag.withCurrent(point)
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
                    // A compound holds only references, so moving the wrapper
                    // alone would move nothing at all.
                    document.translateIncludingChildren(
                        withIDs: editor.selection, by: delta)
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
        // A pen click adds a point to the in-progress path, which is editor
        // state rather than document state, so it bypasses the drag/undo
        // machinery entirely.
        if editor.tool.isPathTool {
            editor.drag = nil
            addPathPoint(point)
            return
        }

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

        case .reshaping(let id, let handle, _, _):
            file.commitGesture(reshapeActionName(for: id, handle: handle),
                               from: snapshot,
                               undoManager: undoManager)

        case .marquee:
            let picked = Set(document.rootPrimitives(intersecting: drag.rect).map(\.id))
            // An additive marquee unions with what was selected before it
            // began; a plain one replaces.
            editor.selection = additiveMarquee ? marqueeBase.union(picked) : picked

        case .inert:
            // A shift-click already changed the selection on mouse-down; there
            // is nothing to finish and no gesture to commit.
            break
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

    /// A semantic name for a reshape, so the undo menu reads "Resize Circle"
    /// rather than a bare "Reshape".
    private func reshapeActionName(for id: PrimitiveID,
                                   handle: PrimitiveHandle) -> String {
        let kind = document.primitive(withID: id)?.kindName ?? "Primitive"
        let verb: String
        switch handle {
        case .center:
            verb = "Move"
        case .radius, .arcRadius, .corner:
            verb = "Resize"
        case .lineStart, .lineEnd, .arcStart, .arcEnd, .vertex:
            verb = "Edit"
        case .cornerRadius:
            verb = "Round"
        }
        return "\(verb) \(kind)"
    }
}
