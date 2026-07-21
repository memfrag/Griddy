//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI

struct MenuBarWindow: Scene {
    var body: some Scene {
        MenuBarExtra {
            MenuBarPopup()
        } label: {
            Image(systemName: "hammer")
        }
        .menuBarExtraStyle(.window)
        //.menuBarExtraStyle(.menu)
    }
}
