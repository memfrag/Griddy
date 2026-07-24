//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyGeometry
import GriddyDocument

/// Transient editing state for one document window.
///
/// Deliberately separate from the document: the active tool, the selection and
/// an in-flight drag are UI state and must never be persisted. See spec 23.2.
@Observable
final class CanvasEditor {

    var tool: Tool = .select

    /// The drawing tool space interrupted, so it can be restored on release in
    /// momentary mode. Nil when space is not holding Select. See
    /// ``SpaceToolBehavior``.
    var toolBeforeSpace: Tool?

    /// Whether a crosshair is currently pushed onto the cursor stack, so the
    /// push is balanced by exactly one pop. Not observed: it mirrors AppKit
    /// state rather than driving the view.
    @ObservationIgnored var crosshairPushed = false
    var selection: Set<PrimitiveID> = []
    var activeWeight: SymbolWeight = .regular

    /// The gesture currently in progress, if any.
    var drag: DragOperation?

    /// Points placed with a path tool (pen) before the path is committed. A
    /// path is built from discrete clicks, so these accumulate outside the
    /// document until the path is finished.
    var pathPoints: [IconPoint] = []

    /// The live cursor while drawing a path, for the rubber-band segment from
    /// the last placed point to where the next one would go.
    var pathCursor: IconPoint?

    /// Discards an in-progress path. Called when finishing, cancelling, or
    /// switching tools.
    func clearPath() {
        pathPoints = []
        pathCursor = nil
    }

    /// How close a click must be to a centerline to select it, in units.
    /// Scaled by zoom at the call site so it stays a constant on-screen target.
    static let hitToleranceInPoints: Double = 6

    func selectOnly(_ id: PrimitiveID?) {
        selection = id.map { [$0] } ?? []
    }

    func toggle(_ id: PrimitiveID) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    /// Drops selected identifiers that no longer exist in the document.
    ///
    /// Without this, deleting a primitive leaves the inspector showing a
    /// selection that cannot be resolved.
    func pruneSelection(against document: SymbolDocument) {
        let known = Set(document.primitives.map(\.id))
        selection.formIntersection(known)
    }
}

/// A gesture in progress.
enum DragOperation {

    /// Drawing a new primitive with a drawing tool.
    case creating(tool: Tool, start: IconPoint, current: IconPoint)

    /// Moving the current selection.
    case moving(start: IconPoint, current: IconPoint)

    /// Reshaping one primitive by dragging a single handle.
    case reshaping(primitiveID: PrimitiveID, handle: PrimitiveHandle,
                   start: IconPoint, current: IconPoint)

    /// Rubber-band selecting.
    case marquee(start: IconPoint, current: IconPoint)

    /// A gesture that has already done its work on mouse-down and ignores the
    /// rest of the drag. A shift-click toggles a shape's selection and arms
    /// this, so a stray movement afterwards does not move the selection.
    case inert

    var start: IconPoint {
        switch self {
        case .creating(_, let start, _), .moving(let start, _),
             .reshaping(_, _, let start, _), .marquee(let start, _):
            start
        case .inert:
            .zero
        }
    }

    var current: IconPoint {
        switch self {
        case .creating(_, _, let current), .moving(_, let current),
             .reshaping(_, _, _, let current), .marquee(_, let current):
            current
        case .inert:
            .zero
        }
    }

    /// The rectangle spanned by the drag, for marquee selection.
    var rect: IconRect {
        PrimitiveGeometry.bounds(containing: [start, current])
            ?? IconRect(origin: start, size: .zero)
    }

    /// The primitive this drag would create, if it is a creation drag.
    var previewPrimitive: IconPrimitive? {
        guard case .creating(let tool, let start, let current) = self else {
            return nil
        }
        return tool.makePrimitive(from: start, to: current)
    }

    func withCurrent(_ point: IconPoint) -> DragOperation {
        switch self {
        case .creating(let tool, let start, _):
            .creating(tool: tool, start: start, current: point)
        case .moving(let start, _):
            .moving(start: start, current: point)
        case .reshaping(let id, let handle, let start, _):
            .reshaping(primitiveID: id, handle: handle, start: start, current: point)
        case .marquee(let start, _):
            .marquee(start: start, current: point)
        case .inert:
            .inert
        }
    }
}
