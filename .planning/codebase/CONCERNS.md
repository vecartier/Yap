# Concerns

**Analysis Date:** 2026-03-21

## Thread Safety

- **68 instances of `nonisolated(unsafe)`** used for SwiftUI observation without proper synchronization
- Audio callbacks run on userInteractive DispatchQueue, accessing shared state
- Lock contention risk in `AudioLevel` (NSLock in audio callback hot path)

## Error Handling

- Pervasive `try?` suppression without user feedback, especially in critical I/O (file writes, audio setup)
- API errors from OpenRouter/Ollama often silently swallowed
- No retry logic for transient network failures in LLM calls

## Force Unwraps

- 7 instances of `.first!` force unwraps on system paths that could crash
- URL construction without validation in several places

## Security

- Some API key handling could leak into diagnostics logs
- UserDefaults used for non-sensitive settings but proximity to Keychain code could cause confusion

## Test Coverage

- Core engines untested: TranscriptionEngine (765 lines), SuggestionEngine (676 lines)
- Audio capture has no test coverage (hardware-dependent)
- SessionStore persistence logic untested

## Performance

- Knowledge base stored entirely in memory (not relevant post-strip, but indicative of pattern)
- Synchronous file I/O in some persistence paths could block pipelines
- Hardcoded batch sizes for embedding operations

## Fragile Areas

- Settings migrations not idempotent — could cause issues on repeated runs
- Audio device validation minimal — device hot-swap can leave dangling state
- Meeting detection uses hardcoded app bundle IDs (meeting-apps.json)
- Task cancellation can delay up to 60 seconds in some paths

## Relevance to Fork

Most concerns are inherited and low-priority for the fork. Key ones to watch:
- **Error handling in LLM calls** — directly impacts summary generation reliability
- **Thread safety patterns** — new summary/Slack features will add more async work
- **No test coverage on intelligence layer** — extending NotesEngine without tests is risky
