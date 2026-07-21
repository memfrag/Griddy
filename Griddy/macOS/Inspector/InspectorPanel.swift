//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import SwiftUIToolbox

struct InspectorPanel: View {

    var body: some View {
        InspectorGrid {
            InspectorSectionHeader("Properties")

            GridRow {
                InspectorLabel("Name")
                InspectorTextValue("Example")
            }

            GridRow {
                InspectorLabel("Type")
                InspectorTextValue("Default")
            }

            InspectorDivider()

            InspectorSectionHeader("Details")

            GridRow {
                InspectorLabel("Created")
                InspectorDateField(Date.now)
            }
        }
        .padding(.top, 8)
    }
}
