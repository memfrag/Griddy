//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI

// MARK: - More Stuff Pane

struct MoreStuffPane: View {
    var body: some View {
        Pane {
            VStack {
                dropArea("Drop files here (URL)")
                    .frame(width: 220, height: 140)
                    .dropDestination(for: URL.self) { urls, location in
                        _ = location
                        dump(urls)
                        return true
                    } isTargeted: { isTargeted in
                        print("Is targeted: \(isTargeted)")
                    }

                dropArea("Drop files here (Data)")
                    .frame(width: 220, height: 140)
                    .dropDestination(for: Data.self) { dataArray, location in
                        _ = location
                        dump(dataArray)
                        return true
                    } isTargeted: { isTargeted in
                        print("Is targeted: \(isTargeted)")
                    }

            }
        }
    }
    
    @ViewBuilder func dropArea(_ title: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.2))
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [8, 4], dashPhase: 0))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(title)
        }
    }
}

// MARK: - Preview

#Preview {
    MoreStuffPane()
}
