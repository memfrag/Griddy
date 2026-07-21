//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import SwiftUIToolbox
import Sparkle

struct MainWindow: Scene {
    
    let updater: SPUUpdater
    
    var body: some Scene {

        WindowGroup {
            Sidebar()
                .frame(minWidth: 400, minHeight: 300)
                .background(AlwaysOnTop())
                .appEnvironment(.default)
                #if os(macOS)
                .terminatesAppWhenClosed()
                #endif
        }
        .commands {
            AboutCommand()
            CheckForUpdatesCommand(updater: updater)
            SidebarCommands()
            ExportCommands()
            AlwaysOnTopCommand()
            HelpCommands()

            /// Add a menu with custom commands
            MyCommands()

            // Remove the "New Window" option from the File menu.
            CommandGroup(replacing: .newItem, addition: { })
        }
    }
}
