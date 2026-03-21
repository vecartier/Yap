---
phase: 01-foundation
plan: 01
subsystem: intelligence-removal
tags: [cleanup, kb-removal, dead-code]
dependency_graph:
  requires: []
  provides: [clean-foundation, no-kb-symbols]
  affects: [Models, AppSettings, AppRuntime, ContentView, SessionStore, SettingsView]
tech_stack:
  added: []
  patterns: [migration-step-pattern, actor-safe-settings]
key_files:
  deleted:
    - OpenOats/Sources/OpenOats/Intelligence/KnowledgeBase.swift
    - OpenOats/Sources/OpenOats/Intelligence/SuggestionEngine.swift
    - OpenOats/Sources/OpenOats/Intelligence/VoyageClient.swift
    - OpenOats/Sources/OpenOats/Intelligence/OllamaEmbedClient.swift
    - OpenOats/Sources/OpenOats/Views/SuggestionsView.swift
    - OpenOats/Tests/OpenOatsTests/KnowledgeBaseTests.swift
  modified:
    - OpenOats/Sources/OpenOats/Models/Models.swift
    - OpenOats/Sources/OpenOats/Settings/AppSettings.swift
    - OpenOats/Sources/OpenOats/App/AppRuntime.swift
    - OpenOats/Sources/OpenOats/Views/ContentView.swift
    - OpenOats/Sources/OpenOats/Storage/SessionStore.swift
    - OpenOats/Sources/OpenOats/Views/SettingsView.swift
    - OpenOats/Sources/OpenOats/Views/OverlayContent.swift
    - OpenOats/Tests/OpenOatsTests/AppSettingsTests.swift
    - OpenOats/Tests/OpenOatsTests/SessionStoreTests.swift
    - OpenOats/Tests/OpenOatsTests/TranscriptStoreTests.swift
decisions:
  - "Remove KB types entirely from SessionRecord (suggestions, kbHits, suggestionDecision, surfacedSuggestionText) rather than making them optional — old JSONL files with those fields decode cleanly via Codable ignoring unknown keys"
  - "Add removeStaleKBKeychainEntriesIfNeeded migration step to delete voyageApiKey and openAIEmbedApiKey from Keychain on next launch"
  - "OverlayContent stripped to volatileThemText only — no suggestion display without KB"
metrics:
  duration_minutes: 10
  tasks_completed: 2
  files_modified: 10
  files_deleted: 6
  completed_date: "2026-03-21"
---

# Phase 01 Plan 01: KB Removal Summary

**One-liner:** Deleted six Knowledge Base Intelligence files and surgically excised all KB symbols, embedding settings, and suggestion UI from six source files, leaving a zero-error build with MeetingStateTests still green.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Delete KB files and test file | 240f18c | 6 files deleted |
| 2 | Scrub KB references from all remaining source files | 268718f | 10 files modified |

## Verification

- `swift build` exits with 0 errors
- `grep -r "KnowledgeBase|SuggestionEngine|EmbeddingProvider|VoyageClient|OllamaEmbedClient" OpenOats/Sources/` — no matches
- `grep "suggestionEngine" OpenOats/Sources/OpenOats/Storage/SessionStore.swift` — no matches
- `grep "SuggestionsView" OpenOats/Sources/OpenOats/Views/ContentView.swift` — no matches
- `grep "knowledgeBase|suggestionEngine" OpenOats/Sources/OpenOats/App/AppRuntime.swift` — no matches
- `grep "Knowledge Base|Embedding Provider|chooseKBFolder" OpenOats/Sources/OpenOats/Views/SettingsView.swift` — no matches
- `MeetingStateTests`: 52 tests, 0 failures

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] TranscriptStoreTests used old ConversationState init**
- **Found during:** Task 2 (test run)
- **Issue:** Two tests used `ConversationState(... themGoals: [] suggestedAnglesRecentlyShown: ...)` which no longer compiles after removing those fields
- **Fix:** Updated both test inits to remove the two KB-only fields
- **Files modified:** OpenOats/Tests/OpenOatsTests/TranscriptStoreTests.swift
- **Commit:** 268718f

**2. [Rule 1 - Bug] OverlayContent referenced Suggestion type**
- **Found during:** Task 2
- **Issue:** OverlayContent.swift had `let suggestions: [Suggestion]` and `let isGenerating: Bool` parameters with UI rendering logic for suggestions — would not compile after Suggestion type removal
- **Fix:** Rewrote OverlayContent to show only `volatileThemText`, removed all suggestion display code
- **Files modified:** OpenOats/Sources/OpenOats/Views/OverlayContent.swift
- **Commit:** 268718f

## Self-Check: PASSED

- SUMMARY.md: FOUND
- KnowledgeBase.swift: DELETED (confirmed)
- SuggestionsView.swift: DELETED (confirmed)
- Task 1 commit 240f18c: FOUND
- Task 2 commit 268718f: FOUND
- swift build: 0 errors
- MeetingStateTests: 52/52 passed
