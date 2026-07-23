//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import AppKit

/// Sets the mouse cursor over an area, without intercepting its events.
///
/// SwiftUI has no crosshair `PointerStyle`, so this reaches for AppKit's
/// `NSCursor.crosshair` directly. It works through cursor *rects* — the
/// window's own cursor mechanism — rather than pushing and popping a cursor,
/// which is stateful and easy to leave stuck. `hitTest` returns nil so mouse
/// events pass straight through to the canvas gesture beneath. See spec 8.3.
struct CanvasCursor: NSViewRepresentable {

    /// The cursor to show, or nil to leave the default arrow.
    var cursor: NSCursor?

    func makeNSView(context: Context) -> NSView {
        CursorRectView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? CursorRectView)?.cursor = cursor
    }

    private final class CursorRectView: NSView {

        var cursor: NSCursor? {
            didSet {
                guard cursor != oldValue else { return }
                window?.invalidateCursorRects(for: self)
            }
        }

        override func resetCursorRects() {
            if let cursor {
                addCursorRect(bounds, cursor: cursor)
            }
        }

        // Transparent to the mouse: events reach the SwiftUI canvas below, so
        // the drag gesture is unaffected. Cursor rects apply regardless.
        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
}

extension View {

    /// Shows `cursor` while the pointer is over this view.
    func canvasCursor(_ cursor: NSCursor?) -> some View {
        overlay(CanvasCursor(cursor: cursor))
    }
}
