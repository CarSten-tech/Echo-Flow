import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    // The globally recognized name for our dictation hotkey.
    // We set a default of Cmd+Shift+D as requested originally.
    public static let toggleDictation = Self("toggleDictation", default: .init(.d, modifiers: [.command, .shift]))
}
