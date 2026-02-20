import SwiftUI

/// Main UI element constructed with a NavigationSplitView typical of modern Ventura apps.
public struct MainSidebar: View {
    @State private var selection: SidebarItem? = .home
    
    enum SidebarItem: String, CaseIterable, Identifiable {
        case home = "Home"
        case dictionary = "Dictionary"
        case workflows = "Workflows"
        case models = "Models"
        case styles = "Styles"
        case hotkeys = "Hotkeys"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .home: return "house"
            case .dictionary: return "text.book.closed"
            case .workflows: return "bolt.horizontal"
            case .models: return "cpu"
            case .styles: return "paintbrush"
            case .hotkeys: return "keyboard"
            }
        }
    }
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                NavigationLink(value: item) {
                    Label(item.rawValue, systemImage: item.icon)
                }
            }
            .navigationTitle("EchoFlow")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
            #endif
        } detail: {
            // Main content area based on selection
            if let selection = selection {
                Text("\(selection.rawValue) View")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            } else {
                Text("Select an item")
            }
        }
    }
}
