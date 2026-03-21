# Testing Patterns

**Analysis Date:** 2026-03-21

## Test Framework

**Runner:**
- XCTest (Apple's native test framework)
- Config: `Package.swift` defines `.testTarget` for `OpenOatsTests`

**Assertion Library:**
- XCTest built-in assertions: `XCTAssertEqual()`, `XCTAssertTrue()`, `XCTAssertNotNil()`, `XCTAssertLessThanOrEqual()`, `XCTFail()`

**Run Commands:**
```bash
swift test                    # Run all tests
swift test --filter <name>   # Run filtered tests
```

## Test File Organization

**Location:**
- Tests in `Tests/OpenOatsTests/` directory
- Files: `TranscriptionBackendTests.swift`, `KnowledgeBaseTests.swift`, `SessionStoreTests.swift`, `AppCoordinatorIntegrationTests.swift`, `MeetingStateTests.swift`, `TranscriptStoreTests.swift`, `AppSettingsTests.swift`, `MarkdownMeetingWriterTests.swift`, `MeetingDetectorTests.swift`

**Naming:**
- Test files match source with "Tests" suffix
- Test classes: `final class <Type>Tests: XCTestCase`

**Structure:**
- One test class per source module
- Tests for `/Sources/OpenOats/` organized in `/Tests/OpenOatsTests/`

## Test Structure

**Suite Organization:**
```swift
import XCTest
@testable import OpenOatsKit

final class TranscriptionBackendTests: XCTestCase {

    // MARK: - ParakeetBackend

    func testParakeetV2DisplayName() {
        let backend = ParakeetBackend(version: .v2)
        XCTAssertEqual(backend.displayName, "Parakeet TDT v2")
    }
}
```

**Patterns:**
- MARK sections organize by concern: `// MARK: - ParakeetBackend`
- One assertion per test mostly
- Async tests with `async` keyword: `func testStartSessionSetsCurrentID() async`
- Test helpers as private functions: `private func makeMetadata(...)`

## Async Testing

**Pattern:**
```swift
func testStartSessionSetsCurrentID() async {
    await store.startSession()
    let id = await store.currentSessionID
    XCTAssertNotNil(id)
    await store.endSession()
    await store.deleteSession(sessionID: id!)
}
```

- Async tests declared with `async`
- `await` for actor method calls
- Cleanup in test body (explicit)

## Mocking

**Framework:** Manual builders, no external mocking framework.

**Patterns:**
```swift
private func makeMetadata(
    title: String? = nil,
    startedAt: Date = Date(timeIntervalSince1970: 1_000_000)
) -> MeetingMetadata {
    MeetingMetadata(
        detectionContext: nil,
        calendarEvent: nil,
        title: title,
        startedAt: startedAt,
        endedAt: nil
    )
}
```

**What to Mock:**
- Builder functions (named `make*`)
- Temporal dependencies with fixed `Date` values
- External service calls in isolation

**What NOT to Mock:**
- Core business logic
- Data structures
- Actor behavior for concurrency tests

## Fixtures and Factories

**Test Data:**
- Builder functions with defaults: `makeMetadata(title: String? = nil, startedAt: Date = ...)`
- Reusable records: `SessionRecord(speaker: .them, text: "Hello", timestamp: Date())`
- Fixed dates: `Date(timeIntervalSince1970: 1_000_000)`

**Location:**
- Private methods in test class
- No separate fixture files

## Coverage

**Requirements:** No explicit requirements enforced.

## Test Types

**Unit Tests:**
- Scope: Individual functions in isolation
- Examples: `testNormalizedWordsLowercases()`, `testJaccardIdenticalStrings()`, `testKebabCaseBasic()`

**Integration Tests:**
- Scope: Multiple components together
- Examples: `testAppendRecordWritesToFile()`, `testStartSessionSetsCurrentID()`

**E2E Tests:**
- UITests in `UITests/OpenOatsUITests/SmokeTests.swift`

## Common Patterns

**Error Testing:**
```swift
func testParakeetTranscribeWithoutPrepareThrows() async {
    let backend = ParakeetBackend(version: .v3)
    do {
        _ = try await backend.transcribe([0.0, 0.1, 0.2], locale: Locale(identifier: "en-US"))
        XCTFail("Expected error")
    } catch is TranscriptionBackendError {
        // Expected
    } catch {
        XCTFail("Unexpected error type: \(error)")
    }
}
```

**Switch Statement Testing:**
```swift
func testParakeetCheckStatusReturnsNeedsDownloadOrReady() {
    let backend = ParakeetBackend(version: .v3)
    let status = backend.checkStatus()
    switch status {
    case .ready, .needsDownload:
        break
    default:
        XCTFail("Expected .ready or .needsDownload, got \(status)")
    }
}
```

**State Machine Testing:**
```swift
func testIdleUserStartedTransitionsToRecording() {
    let meta = makeMetadata(title: "Standup")
    let next = transition(from: .idle, on: .userStarted(meta))
    if case .recording(let m) = next {
        XCTAssertEqual(m.title, "Standup")
    } else {
        XCTFail("Expected .recording, got \(next)")
    }
}
```

**Codable Testing:**
```swift
func testKBChunkCodable() throws {
    let chunk = KBChunk(
        text: "Some knowledge base text",
        sourceFile: "notes.md",
        headerContext: "Section > Subsection",
        embedding: [0.1, 0.2, 0.3]
    )

    let data = try JSONEncoder().encode(chunk)
    let decoded = try JSONDecoder().decode(KBChunk.self, from: data)

    XCTAssertEqual(decoded.text, "Some knowledge base text")
}
```

**Float Accuracy Testing:**
```swift
func testJaccardIdenticalStrings() {
    let score = TextSimilarity.jaccard("hello world", "hello world")
    XCTAssertEqual(score, 1.0, accuracy: 0.001)
}
```

---

*Testing analysis: 2026-03-21*
