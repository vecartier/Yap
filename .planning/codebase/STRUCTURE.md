# Structure

**Analysis Date:** 2026-03-21

## Directory Layout

```
OpenOats/
├── Package.swift                    # SPM manifest (macOS 15+, Swift 6.2)
├── Package.resolved                 # Dependency lockfile
├── OpenOats/
│   ├── Sources/
│   │   ├── OpenOats/                # Main library target (OpenOatsKit)
│   │   │   ├── App/                 # App lifecycle, menu bar, updater
│   │   │   ├── Audio/               # Mic + system audio capture, recorder
│   │   │   ├── Transcription/       # Speech-to-text backends + engine
│   │   │   ├── Intelligence/        # LLM client, suggestions, notes, KB
│   │   │   ├── Meeting/             # Meeting detection, state machine
│   │   │   ├── Models/              # Data structures (Utterance, State)
│   │   │   ├── Storage/             # Session persistence, transcript logging
│   │   │   ├── Settings/            # AppSettings, Keychain helper
│   │   │   ├── Views/               # SwiftUI UI components
│   │   │   └── Resources/           # meeting-apps.json config
│   │   └── OpenOatsApp/             # Executable entry point
│   └── Tests/                       # Unit tests
```

## Key Locations

| What | Where |
|------|-------|
| App entry | `OpenOats/Sources/OpenOatsApp/` |
| Session orchestrator | `OpenOats/Sources/OpenOats/App/AppCoordinator.swift` |
| State machine | `OpenOats/Sources/OpenOats/Meeting/MeetingState.swift` |
| Mic capture | `OpenOats/Sources/OpenOats/Audio/MicCapture.swift` |
| System audio | `OpenOats/Sources/OpenOats/Audio/SystemAudioCapture.swift` |
| Transcription engine | `OpenOats/Sources/OpenOats/Transcription/TranscriptionEngine.swift` |
| LLM client | `OpenOats/Sources/OpenOats/Intelligence/OpenRouterClient.swift` |
| Notes generation | `OpenOats/Sources/OpenOats/Intelligence/NotesEngine.swift` |
| Suggestion engine | `OpenOats/Sources/OpenOats/Intelligence/SuggestionEngine.swift` |
| Knowledge base | `OpenOats/Sources/OpenOats/Intelligence/KnowledgeBase.swift` |
| Transcript store | `OpenOats/Sources/OpenOats/Storage/TranscriptStore.swift` |
| Session store | `OpenOats/Sources/OpenOats/Storage/SessionStore.swift` |
| Settings | `OpenOats/Sources/OpenOats/Settings/AppSettings.swift` |
| Views | `OpenOats/Sources/OpenOats/Views/` |

## Where to Add New Code

- **Solo mode logic** → `Audio/` (mic-only capture variant) + `Meeting/` (new meeting type)
- **Summary engine** → `Intelligence/` (extend or sibling to NotesEngine)
- **Slack integration** → New `Slack/` directory under `OpenOats/Sources/OpenOats/`
- **Post-meeting share UI** → `Views/` (new share screen view)
- **Channel memory/settings** → `Settings/AppSettings.swift` (extend existing)

## Naming Conventions

- Files named after primary type: `MicCapture.swift` contains `MicCapture` class
- Engines suffix: `TranscriptionEngine`, `SuggestionEngine`, `NotesEngine`
- Stores suffix: `TranscriptStore`, `SessionStore`
- Backends suffix: `ParakeetBackend`, `WhisperKitBackend`
- Actors used for persistence: `SessionStore`, `TranscriptLogger`
- @Observable for UI-bound state: `AppCoordinator`, `TranscriptStore`
