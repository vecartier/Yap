# Architecture

**Analysis Date:** 2026-03-21

## Pattern

Event-driven state machine architecture with Observable reactivity and actor-based persistence.

**Core pattern:** `MeetingState` (pure state machine) → `AppCoordinator` (orchestrator, @Observable) → Views (SwiftUI/AppKit)

## Layers

1. **State Machine** — `MeetingState.swift`: Pure enum-based state machine (idle → recording → ending → idle). No side effects.
2. **Coordinator** — `AppCoordinator.swift`: @Observable @MainActor orchestrator. Owns all engines, manages lifecycle, triggers side effects on state transitions.
3. **Audio** — `MicCapture.swift`, `SystemAudioCapture.swift`, `AudioRecorder.swift`: Dual-channel capture via AVAudioEngine (mic) + Core Audio process taps (system). Streams PCM buffers via AsyncStream.
4. **Transcription** — `TranscriptionEngine.swift`, `StreamingTranscriber.swift`, backends (`ParakeetBackend`, `Qwen3Backend`, `WhisperKitBackend`): VAD-based streaming transcription with partial/final callbacks.
5. **Intelligence** — `SuggestionEngine.swift`, `NotesEngine.swift`, `OpenRouterClient.swift`: 5-stage suggestion pipeline, LLM-based notes generation, OpenAI-compatible streaming client.
6. **Storage** — `TranscriptStore.swift` (@Observable), `SessionStore.swift` (actor), `TranscriptLogger.swift` (actor): In-memory store for UI + deferred JSONL persistence + plain text logging.
7. **Models** — `Models.swift`, `MeetingTypes.swift`: Utterance, Speaker, ConversationState, MeetingMetadata.
8. **Settings** — `AppSettings.swift`: UserDefaults + Keychain for API keys.
9. **Views** — SwiftUI views rendered in AppKit menu bar app.

## Data Flow

```
Mic/System Audio → AVAudioEngine/CoreAudio
  → AsyncStream<PCMBuffer>
    → StreamingTranscriber (VAD + chunking)
      → TranscriptionBackend.transcribe()
        → Utterance
          → TranscriptStore (in-memory, UI binding)
          → SessionStore (actor, JSONL persistence)
          → TranscriptLogger (actor, plain text)
          → SuggestionEngine (intelligence pipeline)
```

## Key Abstractions

- **AsyncStream** for audio buffer delivery
- **Actor isolation** for thread-safe persistence (SessionStore, TranscriptLogger)
- **@Observable** for SwiftUI reactivity (AppCoordinator, TranscriptStore)
- **Protocol-based backends** (TranscriptionBackend) for swappable models
- **Deferred writes** in SessionStore (5-second delay to capture pipeline results)

## Entry Points

- `OpenOatsApp.swift` — App entry, creates AppCoordinator
- `AppCoordinator.swift` — Session start/stop, engine lifecycle
- `MeetingState.swift` — State transitions via events
