//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import Sparkle
import SwiftUIToolbox
import GriddyDocument

/// The document window scene. See spec 8.1.
struct DocumentWindow: Scene {

    let updater: SPUUpdater

    var body: some Scene {
        DocumentGroup(newDocument: { SymbolDocumentFile() }) { configuration in
            DocumentWindowContent(file: configuration.document)
                .appEnvironment(.default)
        }
        .commands {
            AboutCommand()
            CheckForUpdatesCommand(updater: updater)
            SidebarCommands()
            HelpCommands()
        }
    }
}

/// The three-column document layout: sidebar, canvas, inspector, with a
/// validation and preview strip along the bottom. See spec 8.1.
private struct DocumentWindowContent: View {

    @ObservedObject var file: SymbolDocumentFile
    @State private var selection: SidebarSelection? = .symbol
    @State private var isInspectorPresented = true

    /// Explicit rather than left to SwiftUI's discretion, so the sidebar's
    /// visibility is deterministic instead of something the split view may
    /// decide to change while resolving width pressure.
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            DocumentSidebar(document: $file.package.document,
                            selection: $selection)
        } detail: {
            // Whatever goes in this column must be horizontally compressible.
            //
            // `.inspector()` claims its width as a safe-area inset on the
            // window-level NSSplitView behind NavigationSplitView. Any hard
            // minimum width in here is added to this column's minimum, which
            // the split view must then find somewhere; with the inspector open
            // there is nothing left to take, so it squeezes the sidebar below
            // its own minimum and the sidebar rows clip off the left edge of
            // the window. The tell is that closing the inspector fixes it.
            //
            // Measured: the sidebar's overflow scaled directly with the bottom
            // strip's declared minimum width. Keep this column free of hard
            // minimums, and never introduce a VSplitView or a nested
            // NavigationSplitView here.
            VStack(spacing: 0) {
                SymbolCanvasView(document: file.document)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                BottomStrip(document: file.document)
            }
        }
        .inspector(isPresented: $isInspectorPresented) {
            DocumentInspector(document: file.document, selection: selection)
                .inspectorColumnWidth(min: 260, ideal: 300, max: 400)
        }
        .navigationTitle(file.document.metadata.name)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    isInspectorPresented.toggle()
                } label: {
                    Label("Toggle Inspector", systemImage: "sidebar.trailing")
                }
            }
        }
        // Deliberately modest. The bottom strip is compressible (flexible
        // validation column, scrolling preview row), so the detail column can
        // shrink and the sidebar survives with the inspector open. Inflating
        // this to buy space would hide a layout problem rather than fix one.
        //
        // Note also that the bottom strip is a `safeAreaInset`, not a
        // `VSplitView`. An NSSplitView-backed container inside the region that
        // `.inspector()` insets produces unsatisfiable constraints, and must
        // not be introduced here later.
        .frame(minWidth: 900, minHeight: 620)
    }
}
