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

    var body: some View {
        NavigationSplitView {
            DocumentSidebar(document: $file.package.document,
                            selection: $selection)
        } detail: {
            SymbolCanvasView(document: file.document)
                .safeAreaInset(edge: .bottom, spacing: 0) {
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
