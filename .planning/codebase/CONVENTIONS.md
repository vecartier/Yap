# Coding Conventions

**Analysis Date:** 2026-03-21

## Naming Patterns

**Files:**
- CamelCase for Swift files, one primary type per file: `AppCoordinator.swift`, `KnowledgeBase.swift`, `TranscriptionBackend.swift`
- Utility files group related enums/structs by function: `Models.swift`, `MeetingTypes.swift`
- Suffixed types by category: `*Engine` (processors), `*Store` (persistence), `*Client` (API calls), `*Backend` (protocol implementations)

**Functions:**
- camelCase for all function names, leading with verb when appropriate: `startSession()`, `appendRecord()`, `checkStatus()`, `formatRelativeTimestamp()`
- Private functions prefixed with underscore only for internal state properties, not functions themselves: `private func drainQueue()`
- Test functions follow pattern `test<Scenario>`: `testIdleUserStartedTransitionsToRecording()`, `testNormalizedWordsLowercases()`, `testKebabCaseBasic()`

**Variables:**
- camelCase for all local and instance variables: `currentSessionID`, `pendingWrites`, `inFlightCount`, `maxConcurrent`
- Private properties use underscore prefix with backing properties: `@ObservationIgnored nonisolated(unsafe) private var _selectedTemplate: MeetingTemplate?` with public getter/setter via `selectedTemplate`
- Constants in camelCase: `minimumWordCount = 5`, `maxConcurrent = 3`

**Types:**
- PascalCase for all types: `enum Speaker`, `struct Utterance`, `struct SessionRecord`, `class AppCoordinator`, `protocol TranscriptionBackend`
- Error enums suffixed with `Error`: `TranscriptionBackendError`, `TranscriptionEngineError`, `VoyageError`, `OpenRouterError`
- Enum cases use camelCase: `.ready`, `.needsDownload`, `.recording`, `.idle`

## Code Style

**Formatting:**
- 4-space indentation (Swift standard)
- One statement per line, line length not restricted but generally readable
- Trailing closures used when last parameter is a closure
- Blank line between logical sections

**Linting:**
- Uses SwiftLint (inferred from project context)
- No strict enforcement documented, but follows standard Swift conventions

**Access Modifiers:**
- `private` for implementation details
- `nonisolated(unsafe)` for actor properties that are thread-safe by design
- `private(set)` for computed properties with public getters but private setters
- `@ObservationIgnored` on private backing properties when using `@Observable` macro

## Import Organization

**Order:**
1. System frameworks (`import Foundation`, `import AppKit`, `import SwiftUI`)
2. Observation framework (`import Observation`)
3. Custom package imports (`@testable import OpenOatsKit`)

**Path Aliases:**
- No path aliases detected; imports use full module paths: `@testable import OpenOatsKit`

## Error Handling

**Patterns:**
- Error types conform to `Error` protocol, often implementing `LocalizedError` for user-facing messages
- Errors defined as enums close to usage site: in `TranscriptionBackend.swift`, `VoyageClient.swift`
- Error propagation via `throws` and `async throws` functions
- Error reporting via dedicated callbacks: `onWriteError: (@Sendable (String) -> Void)?` in `SessionStore`
- Guard statements with early return pattern: `guard let fileHandle else { reportWriteError(...); return }`
- Do-catch blocks for fallible operations: `do { let data = try encoder.encode(record) } catch { reportWriteError(...) }`

**Examples:**
- `TranscriptionBackendError.notPrepared` - simple case indicating precondition not met
- `VoyageError` enum with cases for network, validation, and API errors
- `LocalizedError` conformance provides `errorDescription` for UI display

## Logging

**Framework:** No explicit logging framework detected; uses `os.Logger` from OSLog when needed.

**Patterns:**
- Logger initialized with subsystem and category: `private let logger = Logger(subsystem: "com.openoats.app", category: "MeetingDetection")`
- Logging appears minimal in production code, focused on error cases
- Console output in tests via `print()` and assertion messages

## Comments

**When to Comment:**
- MARK sections used extensively to organize code logically: `// MARK: - Idle State Tests`, `// MARK: - Private`
- Comments explain "why" for non-obvious decisions: `/// Hardcoded cheap model for refinement (keeps cost low).`
- Protocol documentation explains contract and usage constraints

**JSDoc/TSDoc:**
- Triple-slash `///` documentation comments used for public types and functions
- Documentation explains purpose, parameters, and behavior: `/// Refines utterances by cleaning up filler words and fixing punctuation via LLM.`
- Extended documentation for complex functions with context about lifecycle

## Function Design

**Size:** Functions range from 2-30 lines typically; larger functions (50+ lines) split into private helpers.

**Parameters:**
- Named parameters used consistently; trailing closure when callback is last parameter
- Default parameters used for optional configuration: `func index(folderURL: URL) async`
- Optionals preferred over sentinel values

**Return Values:**
- Explicit return types required (no implicit returns in Swift)
- Async/await preferred over completion handlers: `async throws -> String` rather than closure-based callbacks
- Result types used in error cases that require recovery: enum variants for success/failure states

## Module Design

**Exports:**
- Package structure exposes single target: `OpenOatsKit` (main library)
- No explicit public/internal distinctions documented; Swift package default is internal
- Consumers use `@testable import OpenOatsKit` to access internal types in tests

**Barrel Files:**
- No barrel/index files detected; imports are direct to module: `@testable import OpenOatsKit` accesses all internal types

## Swift Concurrency & Concurrency Patterns

**Actors:**
- Used extensively for thread-safe mutable state: `actor SessionStore`, `actor TranscriptRefinementEngine`
- `@MainActor` for UI-bound coordinators: `@MainActor final class AppCoordinator`
- `@Observable` macro from Observation framework for reactive state management

**Task Patterns:**
- Task.sleep with Duration enum: `try? await Task.sleep(for: .seconds(5))`
- Task groups for bounded concurrency: `await withTaskGroup(of: Void.self) { group in ... }`
- Weak self captures in Task closures to avoid memory cycles

**Sendable:**
- Types marked `Sendable` for safe concurrent access: `struct Utterance: Identifiable, Codable, Sendable`
- Enums and structs with Sendable types are automatically Sendable

---

*Convention analysis: 2026-03-21*
