//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyDocument

/// Undo-aware editing.
///
/// Undo is implemented by snapshotting the document value rather than by
/// writing an inverse for every command. The document *is* the design intent,
/// so a snapshot loses nothing, and it stays correct for edits whose inverse is
/// awkward to compute -- notably the constraint-induced cascades coming in
/// Milestone 4. Action names remain semantic, which is what the user sees.
/// Documents are small by design, so the cost is not a concern. See spec 16.4
/// and 23.3.
extension SymbolDocumentFile {

    /// Performs a discrete edit as one undo step.
    func perform(_ actionName: String,
                 undoManager: UndoManager?,
                 _ mutate: (inout SymbolDocument) -> Void) {
        let before = package.document
        mutate(&package.document)
        guard package.document != before else {
            return
        }
        registerUndo(actionName, restoring: before, undoManager: undoManager)
    }

    /// Captures the state to return to when the current gesture is committed.
    ///
    /// Paired with ``commitGesture(_:from:undoManager:)``. Everything between
    /// the two collapses into a single undo step, including any geometry moved
    /// as a side effect. See spec 16.4.
    func beginGesture() -> SymbolDocument {
        package.document
    }

    /// Closes a gesture opened by ``beginGesture()``.
    ///
    /// A gesture that changed nothing registers no undo step, so a stray click
    /// does not litter the undo stack.
    func commitGesture(_ actionName: String,
                       from snapshot: SymbolDocument,
                       undoManager: UndoManager?) {
        guard package.document != snapshot else {
            return
        }
        registerUndo(actionName, restoring: snapshot, undoManager: undoManager)
    }

    /// Mutates without touching the undo stack, for in-flight gesture updates.
    func updateWithoutUndo(_ mutate: (inout SymbolDocument) -> Void) {
        mutate(&package.document)
    }

    private func registerUndo(_ actionName: String,
                              restoring snapshot: SymbolDocument,
                              undoManager: UndoManager?) {
        guard let undoManager else {
            return
        }

        // No explicit begin/endUndoGrouping here. UndoManager groups by event
        // already, and an explicit group nested inside that event group takes
        // the action name while the menu reads the top-level group's name --
        // so every edit after the first would keep showing the first one's
        // name. Registering into the automatic event group names the group the
        // menu actually reads.
        undoManager.registerUndo(withTarget: self) { target in
            // AppKit invokes undo on the main thread, so this is a bridge
            // across isolation rather than a hop. It is not the same situation
            // as document serialisation, which genuinely runs off the main
            // actor -- see the note in SymbolDocumentFile.
            MainActor.assumeIsolated {
                // Capture the current state before restoring, so that undoing
                // this undo redoes the edit. This is what makes redo work.
                let redoSnapshot = target.package.document
                target.package.document = snapshot
                target.registerUndo(actionName,
                                    restoring: redoSnapshot,
                                    undoManager: undoManager)
            }
        }
        undoManager.setActionName(actionName)

        // Publish strictly after the name is set, so anything deriving menu
        // titles from the stack recomputes with the new name rather than the
        // previous one.
        noteUndoStackChanged()
    }
}
