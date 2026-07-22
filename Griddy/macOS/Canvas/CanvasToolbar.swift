//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyGeometry
import GriddyDocument

/// The tool palette and canvas controls. See spec 8.5.
struct CanvasToolbar: ToolbarContent {

    @Bindable var editor: CanvasEditor
    @Binding var document: SymbolDocument

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .principal) {
            Picker("Tool", selection: $editor.tool) {
                ForEach(Tool.allCases) { tool in
                    Label(tool.label, systemImage: tool.systemImage)
                        .tag(tool)
                }
            }
            .pickerStyle(.segmented)
            .labelStyle(.iconOnly)
            .help("Drawing tool")
        }

        ToolbarItemGroup(placement: .automatic) {
            Picker("Master", selection: $editor.activeWeight) {
                ForEach(SymbolWeight.authored, id: \.self) { weight in
                    Text(weight.rawValue.capitalized).tag(weight)
                }
            }
            .pickerStyle(.menu)
            .help("Active weight master")

            Toggle(isOn: $document.grid.showsPrimaryGrid) {
                Label("Grid", systemImage: "grid")
            }
            .help("Show grid")
        }
    }
}

/// Menu commands that act on the current document window.
///
/// Delete lives here rather than on the canvas so it works from the menu bar
/// and picks up the standard keyboard shortcut.
struct EditCommands: Commands {

    @FocusedValue(\.canvasEditor) private var editor
    @FocusedValue(\.documentFile) private var file
    @FocusedValue(\.windowUndoManager) private var undoManager

    @FocusedValue(\.undoState) private var undoState

    /// The window's undo manager, flattened from the doubly-optional focused
    /// value.
    private var undo: UndoManager? {
        undoManager ?? nil
    }

    var body: some Commands {
        // SwiftUI's built-in Undo and Redo items ignore the undo manager's
        // action name and always read a bare "Undo" / "Redo", losing the
        // semantic naming the edits go to the trouble of setting. Owning the
        // items lets them use AppKit's own menu titles. See spec 16.4.
        //
        // The titles come from `undoState` rather than being read off the
        // UndoManager here. UndoManager is not observable, so a title read
        // directly from it is computed once and then frozen: the menu would
        // keep showing the first action name no matter what happened after.
        // `undoState` is recomputed by the document view on every edit, so
        // changing it is what drives this menu to refresh.
        CommandGroup(replacing: .undoRedo) {
            Button(undoState?.undoTitle ?? "Undo") {
                undo?.undo()
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!(undoState?.canUndo ?? false))

            Button(undoState?.redoTitle ?? "Redo") {
                undo?.redo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!(undoState?.canRedo ?? false))
        }

        // Named for the canvas rather than reusing the plain "Delete" and
        // "Select All", which AppKit already contributes to the Edit menu for
        // text contexts. Two identically-named items in one menu is worse than
        // slightly longer names.
        CommandGroup(after: .pasteboard) {
            Button("Delete Selection") {
                delete()
            }
            .keyboardShortcut(.delete, modifiers: [])
            .disabled(editor?.selection.isEmpty ?? true)

            Button("Select All Primitives") {
                guard let editor, let file else {
                    return
                }
                editor.selection = Set(
                    file.document.primitivesInDrawOrder
                        .filter { file.document.isEditable($0.id) }
                        .map(\.id)
                )
            }
            .keyboardShortcut("a", modifiers: .command)
            .disabled(file == nil)

            Divider()
        }
    }

    private func delete() {
        guard let editor, let file, !editor.selection.isEmpty else {
            return
        }
        let ids = editor.selection
        let name = ids.count == 1
            ? "Delete \(file.document.primitive(withID: ids.first ?? PrimitiveID())?.kindName ?? "Primitive")"
            : "Delete \(ids.count) Primitives"

        file.perform(name, undoManager: undoManager ?? nil) { document in
            document.removePrimitives(withIDs: ids)
        }
        editor.selection = []
    }
}

// MARK: - Focused values

/// Plumbing so menu commands can reach the focused window's editing state.
/// SwiftUI commands live outside the view hierarchy and have no other route to
/// per-window state.

/// A snapshot of the undo stack's presentation state.
///
/// Exists because `UndoManager` is not observable. The document view rebuilds
/// this on every edit and publishes it as a focused value, which is what makes
/// the Undo and Redo menu titles refresh.
struct UndoState: Equatable {

    var undoTitle: String
    var redoTitle: String
    var canUndo: Bool
    var canRedo: Bool

    /// Included so the value always differs after a registration, even when the
    /// titles happen to be unchanged. Without it an equal value would not
    /// propagate as a new focused value.
    var revision: Int

    init(_ undoManager: UndoManager?, revision: Int) {
        undoTitle = undoManager?.undoMenuItemTitle ?? "Undo"
        redoTitle = undoManager?.redoMenuItemTitle ?? "Redo"
        canUndo = undoManager?.canUndo ?? false
        canRedo = undoManager?.canRedo ?? false
        self.revision = revision
    }
}

struct UndoStateFocusedKey: FocusedValueKey {
    typealias Value = UndoState
}

struct CanvasEditorFocusedKey: FocusedValueKey {
    typealias Value = CanvasEditor
}

struct DocumentFileFocusedKey: FocusedValueKey {
    typealias Value = SymbolDocumentFile
}

struct UndoManagerFocusedKey: FocusedValueKey {
    typealias Value = UndoManager?
}

extension FocusedValues {

    var undoState: UndoState? {
        get { self[UndoStateFocusedKey.self] }
        set { self[UndoStateFocusedKey.self] = newValue }
    }

    var canvasEditor: CanvasEditor? {
        get { self[CanvasEditorFocusedKey.self] }
        set { self[CanvasEditorFocusedKey.self] = newValue }
    }

    var documentFile: SymbolDocumentFile? {
        get { self[DocumentFileFocusedKey.self] }
        set { self[DocumentFileFocusedKey.self] = newValue }
    }

    var windowUndoManager: UndoManager?? {
        get { self[UndoManagerFocusedKey.self] }
        set { self[UndoManagerFocusedKey.self] = newValue }
    }
}
