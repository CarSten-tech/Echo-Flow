# `EchoFlow`

High-performance audio routing and automation engine for macOS.

## Overview

EchoFlow is a menu bar application that listens for a global hotkey, captures audio using `AudioEngine`, transcribes it using `WhisperKitService`, and then semantically routes the natural language using `IntentRouter`.

The core modules are:

- **Audio Capture**: Handles microphone permissions, privacy shielding, and PCM buffer extraction.
- **Routing**: Determines whether the user desires to dictate text or execute a system command (e.g. "open Safari").
- **Automation**: Synthesizes Cmd+V key events to paste text instantly (`TextInjector`) or runs native AppleScripts via `WorkflowHandler`.

## Topics

### Core Services

- `AppCoordinator`
- `AudioEngine`

### Routing & Intelligence

- `IntentRouter`
- `GeminiProvider`
- `LocalInferenceProvider`

### Automation Execution

- `TextInjector`
- `WorkflowHandler`
