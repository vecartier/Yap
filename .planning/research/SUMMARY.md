# Project Research Summary

**Project:** OpenOats fork — MeetingScribe (auto-summary + Slack integration milestone)
**Domain:** macOS meeting transcription — structured summary generation, solo mode, Slack sharing
**Researched:** 2026-03-21
**Confidence:** HIGH

## Executive Summary

This milestone extends an already-functional Swift 6.2 / macOS 15+ meeting transcription app with three capabilities: solo/mic-only recording mode, automatic structured summary generation on session end, and Slack delivery via incoming webhooks. The existing codebase provides strong foundations — `OpenRouterClient` for LLM calls, `AppCoordinator` for session lifecycle, `MicCapture` for audio, and Keychain-backed `AppSettings` — meaning no new Swift Package dependencies are required. All new capabilities build entirely on Foundation, AppKit, and SwiftUI already in the project.

The recommended approach is a strict three-phase build order derived from hard architectural dependencies: (1) solo mode and knowledge-base removal first to clear the codebase of dead code and establish correct audio engine initialization patterns; (2) `SummaryEngine` second, hooked into `AppCoordinator.finalizeCurrentSession()` with a two-phase structured JSON prompt to minimize hallucination; (3) Slack integration and the post-meeting share UI last, built on top of the summary output. This order is non-negotiable — the share screen has no value without a summary, and the summary pipeline must be designed before the share UI is wired or the finalization race condition will be baked in.

The two highest risks are both implementation traps rather than architectural unknowns. First, Slack incoming webhooks are channel-locked — the "channel picker" in PROJECT.md must be re-scoped to a "webhook picker" where users configure named webhook entries rather than selecting from a dynamic channel list. Second, the existing `NotesEngine` 60K-character truncation strategy silently discards the middle portion of long meetings; a new `SummaryEngine` must use token-aware chunking with explicit user notification rather than reusing the existing truncation unchanged. Both pitfalls are well-documented and entirely avoidable if addressed at the design phase of each respective feature.

## Key Findings

### Recommended Stack

The milestone requires zero new Swift Package Manager dependencies. All needed capabilities — HTTP (URLSession), JSON (Codable/JSONEncoder), clipboard (NSPasteboard), and UI state (SwiftUI @Observable) — are already present in the project or the OS. The existing `OpenRouterClient.complete()` non-streaming path is extended to support `response_format: json_schema` for structured output; Ollama requires a different top-level `format` field due to a documented incompatibility with the OpenAI structured-output syntax (GitHub issue #10001). Slack webhooks are plain `POST application/json` to a `hooks.slack.com` URL — no Slack SDK is needed or appropriate.

**Core technologies:**
- URLSession (Foundation, built-in): Slack webhook HTTP POST — already used in `OpenRouterClient`, zero new dependencies
- Swift Codable + JSONEncoder (built-in): Slack Block Kit payload construction — same pattern as `ChatRequest`
- `OpenRouterClient.complete()` (existing): Non-streaming structured JSON summary generation — extend with optional `response_format` field
- SwiftUI `@Observable` (built-in): Share screen state management — consistent with existing `NotesEngine` and `AppCoordinator` patterns
- macOS `NSPasteboard` (AppKit, built-in): Copy-to-clipboard fallback — zero-config sharing path

**Critical version note:** Ollama structured output requires `format` at top-level in the request body (not nested in `response_format`). Detect provider at runtime and branch accordingly; fall back to `extractLLMSections()` markdown parsing on JSON decode failure.

### Expected Features

Structured summaries (key decisions, action items, discussion points, open questions) and readable Slack formatting are table stakes — every major competitor delivers these and users will consider their absence a product defect. Solo/mic-only mode is equally expected for any tool that claims to handle in-person meetings. The post-meeting review screen before sending is a deliberate UX differentiator — all major competitors (Fireflies, Fathom, Otter) auto-fire to Slack; the review step is the primary trust-building mechanism.

**Must have (table stakes):**
- Structured summary with 4 sections (decisions, action items, discussion points, open questions) — baseline user expectation
- Action items with owners extracted from transcript context — distinguishes "useful" from "vague"
- Copy-to-clipboard export — zero-config fallback for users without a webhook
- Immediate summary availability after session end — delays erode trust
- Readable Slack Block Kit formatting — header + section blocks, not a text wall
- Solo mode (mic-only, manual start) — unlocks in-person use and voice memos
- Strip knowledge base UI and code — PROJECT.md direction, removes dead weight

**Should have (competitive advantage):**
- Post-meeting review screen before any sharing action — deliberate differentiator vs. auto-fire competitors
- Webhook-based Slack with no OAuth/admin approval — self-service setup is the key friction win
- Local LLM support (Ollama) for privacy-sensitive meetings — no competitor offers this
- Recurring meeting webhook memory (auto-populate last-used webhook) — removes the top friction point in post-meeting sharing
- Meeting type context in summary prompt — standup vs. client call vs. planning have different useful structures

**Defer (v2+):**
- Summary template customization — only if users find 4 default sections insufficient
- Multiple Slack workspace profiles — complexity not justified for a personal tool
- Summary search across sessions — defer until history usage patterns are understood

### Architecture Approach

The new components fit cleanly into the existing layered architecture without restructuring it. A new `SummaryEngine` actor (sibling to `NotesEngine`) handles structured LLM summarization. A new `SlackService` actor and `SlackFormatter` handle Block Kit payload construction and webhook delivery. A `ChannelStore` actor persists named webhook configurations. A new `PostMeetingShareUI` window (not a popover — needs screen space) presents the summary and wires all sharing actions. `AppCoordinator` is extended at two points: `startSession()` gets a `MeetingMode` enum to control audio engine initialization, and `finalizeCurrentSession()` gets a summary generation hook after transcript finalization completes.

**Major components:**
1. `SummaryEngine` (new actor) — structured LLM summarization; two-phase grounding+formatting prompt; triggered from `AppCoordinator.finalizeCurrentSession()` after transcript drain
2. `SlackService` + `SlackFormatter` (new, `Slack/` directory) — Block Kit payload construction with per-block 3K-char enforcement; webhook POST via URLSession
3. `PostMeetingShareUI` (new NSWindow/NSPanel) — summary review, webhook picker, send/copy/save actions; driven by `@Observable` summary state on `AppCoordinator`
4. `ChannelStore` (new actor) — named webhook configurations (label + Keychain URL); last-used-per-meeting-app memory in UserDefaults
5. `MeetingMode` enum (new, in `AppCoordinator`) — `.call` vs `.solo`; controls whether `SystemAudioCapture` is initialized at session start

### Critical Pitfalls

1. **Webhook is channel-locked, not channel-selectable** — The PROJECT.md "channel picker" is impossible with a single webhook URL; re-scope to a "webhook picker" where users configure named `(label, URL)` pairs in Settings. Address in the Settings/Slack integration phase before designing the share UI data model.

2. **Transcript truncation silently discards the meeting middle** — The existing `NotesEngine` 60K-char strategy keeps first and last 1/3, discarding the middle 1/3. Do not reuse this in `SummaryEngine`; implement token-aware chunking with explicit user notification for long meetings. Address in the summary generation phase when designing the transcript-to-prompt pipeline.

3. **LLM hallucination of action items** — Single-pass prompts generate "helpful-sounding" action items with fabricated owners and deadlines. Use a two-phase prompt: grounding pass (quote exact transcript evidence) then formatting pass. Chain two `OpenRouterClient.complete()` calls. Address in the summary generation phase before implementing `SummaryEngine.generate()`.

4. **Solo mode breaks session lifecycle silently** — Adding a `skipSystemAudio: Bool` flag to the existing `TranscriptionEngine` leaves `AudioHardwareCreateProcessTap()` running; use a factory method or separate initialization path controlled by `MeetingMode` enum instead. Address in the solo mode phase before wiring the menu bar toggle.

5. **Webhook URLs stored in UserDefaults (secret leak)** — Webhook URLs are effectively secrets and must go in Keychain (same pattern as the OpenRouter API key in `AppSettings.swift`), not `@AppStorage` or `UserDefaults`. Address in the Slack integration phase before any share UI is wired.

6. **Share screen shown before transcript finalization completes** — Triggering summary generation from `onChange(of: coordinator.lastEndedSession)` in the UI creates a race; trigger from within `finalizeCurrentSession()` after `sessionStore.awaitPendingWrites()`. Address in the summary generation phase when designing the `AppCoordinator` hook point.

7. **Slack Block Kit 3K-char-per-block limit silently truncates** — HTTP 200 response does not confirm full message display; use one section block per summary category with explicit 3K-char enforcement and truncation with a "see full transcript" note. Address in the Slack formatting phase.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Foundation — Solo Mode + Knowledge Base Removal

**Rationale:** Solo mode has no upstream dependencies and establishes the `MeetingMode` enum and audio engine initialization pattern that later phases reference. Knowledge base removal clears dead code before new features are added, reducing noise during implementation. Both are low-complexity, high-confidence tasks.

**Delivers:** Mic-only recording mode accessible from menu bar; clean codebase with KB surface area removed; `MeetingMode` enum pattern established for Phases 2+

**Addresses features:** Solo mode (mic-only, manual start); strip knowledge base UI and code (P1 from FEATURES.md)

**Avoids pitfalls:** Pitfall 4 (solo mode session lifecycle) — `MeetingMode` enum with factory-method initialization must be established here, not patched later

**Research flag:** Standard patterns — solo mode follows existing `MicCapture` path and `AppCoordinator` session start. No additional research phase needed.

### Phase 2: Summary Engine

**Rationale:** The summary is the core value delivery of this milestone and is a hard upstream dependency for the share screen. It must be designed before the share UI is built or finalization-race and prompt-architecture decisions get locked in by UI assumptions. This phase also requires the most careful design work (two-phase prompting, transcript chunking, provider-specific structured output branching).

**Delivers:** `MeetingSummary` struct generated on every session end; typed output (decisions, action items, discussion points, open questions); saved to `~/Documents/OpenOats/`; `@Observable` summary state driving share screen loading indicator

**Uses:** `OpenRouterClient.complete()` extended with `response_format`; Ollama `format` field branching; `extractLLMSections()` markdown fallback

**Implements:** `SummaryEngine` actor; two-phase grounding+formatting prompt; transcript-to-prompt pipeline with length heuristics; `AppCoordinator.finalizeCurrentSession()` hook after `awaitPendingWrites()`

**Avoids pitfalls:** Pitfall 2 (transcript truncation), Pitfall 3 (hallucinated action items), Pitfall 6 (share screen shown before finalization)

**Research flag:** Needs research-phase attention for the two-phase prompt strategy — the exact prompt structure and grounding pass design should be validated against real meeting transcripts before locking in.

### Phase 3: Slack Integration + Post-Meeting Share UI

**Rationale:** Depends entirely on Phase 2 output. The share UI has no content to display without a `MeetingSummary`. The Slack service and Block Kit formatter can be built in parallel with the share UI since `SlackFormatter` takes a `MeetingSummary` input (defined in Phase 2). Webhook storage (Keychain) and named webhook configuration (Settings) must be designed before the share UI channel-picker UX to avoid the channel-picker pitfall.

**Delivers:** Post-meeting review window showing formatted summary; webhook picker with last-used memory; "Send to Slack" with Block Kit formatted message; "Copy to Clipboard" fallback; inline send success/failure feedback

**Uses:** URLSession + Codable Block Kit structs; `NSPasteboard`; Keychain for webhook URL storage; `UserDefaults` for webhook display labels and last-used-per-meeting-app memory

**Implements:** `SlackService` actor; `SlackFormatter` with per-block 3K-char enforcement; `ChannelStore` actor; `PostMeetingShareUI` NSWindow/NSPanel; `AppSettings` Keychain extension for webhook URLs

**Avoids pitfalls:** Pitfall 1 (webhook channel-lock — webhook picker model), Pitfall 5 (webhook URL in UserDefaults), Pitfall 7 (Block Kit truncation)

**Research flag:** Standard patterns for Block Kit formatting (official docs are complete and high-confidence). The named-webhook UX pattern for webhook-based tools is MEDIUM confidence and should be prototyped early in this phase before full implementation.

### Phase Ordering Rationale

- Phase 1 before Phase 2: `MeetingMode` enum is used in `AppCoordinator.startSession()` which Phase 2 extends at `endSession()`; establishing the enum first avoids merge conflicts
- Phase 2 before Phase 3: `MeetingSummary` struct is the core data contract between the summary engine and the share UI; building the share UI against a stable typed output prevents downstream rework
- Settings/Keychain for webhook storage designed at Phase 3 start: the share UI's channel picker data model depends on the `(label, url)` webhook store being defined; designing it late causes UI rework
- Knowledge base removal in Phase 1: dead code involving `VoyageClient`, `OllamaEmbedClient`, `SuggestionEngine` should be removed before adding new components to keep the diff clean and avoid accidental reuse of removed infrastructure

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2 (Summary Engine):** Two-phase grounding+formatting prompt architecture needs validation against real transcript data before implementation. The exact schema and prompt wording are not settled by this research — they need iteration.
- **Phase 2 (Summary Engine):** Ollama structured output compatibility is MEDIUM confidence; the `format` field behavior may have changed in newer Ollama versions (GitHub issue #10001 may be resolved). Verify against current Ollama release at implementation time.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Solo Mode + KB Removal):** Follows existing `MicCapture` and `AppCoordinator` patterns exactly; no novel integration
- **Phase 3 (Slack / Share UI):** Block Kit formatting and webhook POST are fully documented in official Slack docs (HIGH confidence); implementation is mechanical once the data model is established

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All technology decisions verified against official docs; zero new dependencies; existing patterns confirmed directly from codebase analysis |
| Features | HIGH | Competitor feature landscape cross-verified across multiple sources; table stakes well-established; differentiators grounded in documented Slack limitations |
| Architecture | HIGH | Build order derived from hard code dependencies in `AppCoordinator`; component boundaries match existing codebase patterns; no speculative layering |
| Pitfalls | HIGH | 5 of 7 pitfalls verified directly against codebase source files; 2 verified against official Slack/OpenRouter docs; all prevention strategies are concrete and actionable |

**Overall confidence:** HIGH

### Gaps to Address

- **Ollama `format` field compatibility:** MEDIUM confidence that current Ollama versions handle structured output via the `format` field correctly. Verify at the start of Phase 2 implementation by running a test call against current Ollama before writing production `SummaryEngine` code.
- **Two-phase prompt quality:** Research recommends a grounding+formatting two-pass strategy based on ACM hallucination data but does not validate specific prompt wording. Treat the first real meeting as a prompt-tuning exercise; build a way to swap prompts without recompiling (e.g., externalize to a settings file) for the early validation period.
- **Multi-webhook UX discoverability:** The "webhook picker" pattern is architecturally correct but no evidence was found of its UX being well-studied in comparable personal tools. Prototype the Settings entry flow (add/remove/label webhooks) before the Phase 3 share UI implementation sprint.

## Sources

### Primary (HIGH confidence)
- [Slack Incoming Webhooks official docs](https://docs.slack.dev/messaging/sending-messages-using-incoming-webhooks/) — channel-lock behavior, payload format, modern app vs. legacy distinction
- [Slack Block Kit reference](https://docs.slack.dev/reference/block-kit/blocks/) — character limits per block type, mrkdwn format
- [Slack per-channel webhook blueprint](https://api.slack.com/best-practices/blueprints/per-channel-webhooks) — confirmed one webhook = one channel constraint
- [OpenRouter Structured Outputs docs](https://openrouter.ai/docs/guides/features/structured-outputs) — `response_format` support, `require_parameters` usage
- [OpenRouter Response Healing announcement](https://openrouter.ai/announcements/response-healing-reduce-json-defects-by-80percent) — non-streaming only for JSON repair
- [Ollama Structured Outputs docs](https://docs.ollama.com/capabilities/structured-outputs) — `format` field, GBNF grammar constraints
- Codebase direct analysis: `NotesEngine.swift`, `AppCoordinator.swift`, `OpenRouterClient.swift`, `MicCapture.swift`, `SystemAudioCapture.swift`, `AppSettings.swift`

### Secondary (MEDIUM confidence)
- [Ollama GitHub issue #10001](https://github.com/ollama/ollama/issues/10001) — OpenAI `response_format` incompatibility; may be patched in newer versions
- [Fireflies Slack integration docs](https://fireflies.ai/blog/fireflies-slack-integration/) — competitor feature landscape
- [ACM PACMHCI: LLM-powered Meeting Recap System (2025)](https://dl.acm.org/doi/10.1145/3711074) — 22% action item capture rate, hallucination patterns
- [Top AI notetakers 2026 — AssemblyAI](https://www.assemblyai.com/blog/top-ai-notetakers) — competitor feature comparison

### Tertiary (LOW confidence)
- [Best AI note takers for in-person meetings — plaud.ai](https://www.plaud.ai/blogs/articles/the-7-best-ai-note-taker-for-in-person-meetings-plus-buying-guide) — vendor source; solo mode use cases

---
*Research completed: 2026-03-21*
*Ready for roadmap: yes*
