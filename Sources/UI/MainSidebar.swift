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
            if let selection = selection {
                switch selection {
                case .hotkeys:
                    HotkeySettingsView()
                case .models:
                    ProviderSettingsView()
                case .styles:
                    StylesSettingsView()
                default:
                    Text("\(selection.rawValue) View")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Select an item")
            }
        }
    }
}

/// A dedicated settings panel to modify the appearance of EchoFlow.
struct StylesSettingsView: View {
    @AppStorage("hudSize") private var hudSize: String = "Medium"
    let sizes = ["Small", "Medium", "Large"]
    
    var body: some View {
        Form {
            Section(header: Text("HUD Appearance").font(.headline)) {
                Picker("Pill Size", selection: $hudSize) {
                    ForEach(sizes, id: \.self) { size in
                        Text(size).tag(size)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.bottom, 8)
                
                Text("Changes to the HUD size reflect immediately on the next dictation session.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Styles & Appearance")
    }
}
