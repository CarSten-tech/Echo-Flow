import SwiftUI
import AppKit

/// Sets up the Menu Bar app using `NSApplication.ActivationPolicy.accessory`.
@main
struct EchoFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // We use an empty settings scene because Settings handles the Menu item nicely.
        // The primary window is managed in AppDelegate for finer control, simulating Settings.
        Settings {
            MainSidebar()
                .frame(minWidth: 700, minHeight: 400)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var hud: GlassPillHUD?
    let engine = AudioEngine()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure LSUIElement behavior (No dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        hud = GlassPillHUD()
        
        // Setup MenuBar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "EchoFlow")
        }
        
        setupMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        let toggleHUDItem = NSMenuItem(title: "Toggle Dictation HUD", action: #selector(toggleHUD), keyEquivalent: "d")
        menu.addItem(toggleHUDItem)
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit EchoFlow", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func toggleHUD() {
        if engine.isRecording {
            engine.stopRecording()
            hud?.hide()
        } else {
            do {
                try engine.startRecording()
                hud?.show(transcription: "Listening...", audioLevel: 0.1)
            } catch {
                print("Failed to start audio engine: \\(error)")
            }
        }
    }
    
    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
