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
    var hotkeyManager: HotkeyManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure LSUIElement behavior (No dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        AppLog.info("EchoFlow App Launched. Setup initiating...", category: .general)
        
        hud = GlassPillHUD()
        hotkeyManager = HotkeyManager()
        
        // Link Hotkey to Audio Toggle
        hotkeyManager?.onHotkeyPressed = { [weak self] in
            self?.toggleHUD()
        }
        
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
            AppLog.debug("User requested stop recording.", category: .audio)
            engine.stopRecording()
            hud?.hide()
        } else {
            do {
                AppLog.debug("User requested start recording via Hotkey/Menu.", category: .audio)
                try engine.startRecording()
                hud?.show(transcription: "Listening securely...", audioLevel: 0.1)
                
            } catch PrivacyShield.PrivacyError.secureInputActive {
                AppLog.warning("Recording blocked by Secure Input Shield.", category: .privacy)
                hud?.show(transcription: "🔒 Blocked by Privacy Shield", audioLevel: 0.0)
                
                // Hide after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    if self?.engine.isRecording == false {
                        self?.hud?.hide()
                    }
                }
            } catch {
                AppLog.error("Failed to start audio engine: \(error)", category: .audio)
            }
        }
    }
    
    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
