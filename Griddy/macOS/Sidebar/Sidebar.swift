//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import SwiftUIToolbox

struct Sidebar: View {

    @State var searchText: String = ""

    @State var selection: SidebarPane?

    @State var isInspectorPresented: Bool = true

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                
                Section(header: Text("General")) {
                    
                    NavigationLink(value: SidebarPane.helloWorld) {
                        Label("Hello, World!", systemImage: "text.bubble")
                    }

                    NavigationLink(value: SidebarPane.whatsUp) {
                        Label("What's Up?", systemImage: "questionmark.app.dashed")
                    }
                }
                
                Section(header: Text("More")) {
                    
                    NavigationLink(value: SidebarPane.moreStuff) {
                        Label("More Stuff", systemImage: "ellipsis.circle")
                    }
                }
                
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 180, idealWidth: 180, maxWidth: 300)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                SidebarFooter()
            }
            .searchable(text: $searchText, placement: .sidebar)
        } detail: {
            switch selection {
            case .helloWorld:
                HelloWorldPane()
            case .whatsUp:
                WhatsUpPane()
            case .moreStuff:
                MoreStuffPane()
            default:
                EmptyPane()
            }
        }
        .inspector(isPresented: $isInspectorPresented) {
            InspectorPanel()
                .inspectorColumnWidth(min: 200, ideal: 250, max: 350)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    isInspectorPresented.toggle()
                } label: {
                    Label("Toggle Inspector", systemImage: "sidebar.trailing")
                }
            }
        }
    }
}

#Preview {
    Sidebar()
}
