//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI

/// Canvas and editing preferences.
struct CanvasSettingsTab: View {

    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Picker("Space bar:", selection: $settings.spaceToolBehavior) {
                    ForEach(SpaceToolBehavior.allCases) { behavior in
                        Text(behavior.description).tag(behavior)
                    }
                }
                Text("While a drawing tool is active, the space bar switches to "
                     + "the Select tool — held down and released with "
                     + "\u{201C}Hold to select\u{201D}, or once with "
                     + "\u{201C}Tap to switch\u{201D}.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
    }
}
