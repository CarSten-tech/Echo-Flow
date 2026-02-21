import SwiftUI
import KeyboardShortcuts

/// Settings view for configuring the dictation hotkey and recording mode.
public struct HotkeySettingsView: View {
    @ObservedObject var settings = ModelSettings.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("Recording Mode").font(.headline)) {
                Picker("Activation", selection: $settings.recordingMode) {
                    ForEach(RecordingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                
                switch settings.recordingMode {
                case .pushToTalk:
                    Label("Hold the hotkey to record, release to stop.", systemImage: "hand.tap.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                case .toggleToTalk:
                    Label("Press once to start recording, press again to stop.", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Microphone").font(.headline)) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "mic.badge.plus")
                        Slider(value: $settings.audioGain, in: 0.5...4.0)
                        Text(String(format: "%.1fx", settings.audioGain))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Increase sensitivity if the waveform barely moves when you speak.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Shortcut").font(.headline)) {
                KeyboardShortcuts.Recorder("Dictation Hotkey:", name: .toggleDictation)
                
                Text("This shortcut works globally — from any app.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Hotkeys")
    }
}
