//
//  ContentView.swift
//  Echo Flow
//
//  Created by Carsten Rheidt on 20.02.26.
//

import SwiftUI
import KeyboardShortcuts

struct ContentView: View {
    var body: some View {
        TabView {
            ProviderSettingsView()
                .tabItem {
                    Label("AI Provider", systemImage: "network")
                }
            
            Form {
                Section(header: Text("Global Shortcut")) {
                    KeyboardShortcuts.Recorder("Dictation Shortcut:", name: .toggleDictation)
                    Text("Press and hold this shortcut to record. Release to process.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            LicenseSettingsView()
                .tabItem {
                    Label("License", systemImage: "key.fill")
                }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
    }
}

#Preview {
    ContentView()
}
