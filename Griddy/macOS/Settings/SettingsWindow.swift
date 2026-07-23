//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI

/// Show settings window by using a SettingsLink SwiftUI view.
struct SettingsWindow: Scene {

    private enum Tabs: Hashable {
        case general
        case canvas
    }

    var body: some Scene {
        Settings {
            // The same process-global AppSettings the document windows read, so
            // a change here is observed live by an open canvas.
            tabs
                .environment(AppEnvironment.default.appSettings)
        }
    }

    @ViewBuilder var tabs: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(Tabs.general)

            CanvasSettingsTab()
                .tabItem {
                    Label("Canvas", systemImage: "square.grid.2x2")
                }
                .tag(Tabs.canvas)
        }
        .padding(20)
        .frame(width: 420, height: 180)
    }
}
