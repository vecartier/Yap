# Stack Research

**Domain:** macOS meeting transcription — structured summary generation + Slack integration
**Researched:** 2026-03-21
**Confidence:** HIGH (core decisions), MEDIUM (Slack webhook multi-channel strategy)

---

## Context: What Already Exists

This milestone extends an existing Swift 6.2 / macOS 15+ app. The existing stack is:

- **Audio capture:** FluidAudio 0.7.9 + Core Audio process taps
- **Transcription:** WhisperKit 0.9.0 + FluidAudio (Parakeet, Whisper, Qwen3)
- **LLM client:** Custom `OpenRouterClient` — OpenAI-compatible streaming via URLSession
- **LLM providers:** OpenRouter, Ollama (localhost), MLX (localhost), OpenAI-compatible
- **Notes layer:** `NotesEngine` — streams markdown from LLM into `@Observable` state
- **Storage:** JSONL session logs + markdown files in `~/Documents/OpenOats/`
- **Settings:** `AppSettings` with Keychain-backed API keys
- **Dependencies:** FluidAudio, Sparkle 2.7.0, WhisperKit, LaunchAtLogin-Modern

**Do not re-introduce any of the above.** The research below covers only what the milestone adds.

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| URLSession (Foundation) | Built-in (Swift 6.2) | Slack webhook HTTP POST | Already used for all LLM calls in `OpenRouterClient`. Zero new dependencies. Slack webhooks are plain `POST application/json` — no SDK needed. HIGH confidence. |
| Swift `Codable` + `JSONEncoder` | Built-in | Slack Block Kit payload construction | Block Kit messages are JSON objects. `Codable` structs + `JSONEncoder` produce correct payloads. Same pattern used for `ChatRequest` in `OpenRouterClient`. HIGH confidence. |
| `OpenRouterClient.complete()` (existing) | Existing | Non-streaming structured summary generation | The existing non-streaming `.complete()` path returns raw text. Extend it or add a `completeJSON()` variant that passes `response_format: json_schema` for structured summary output. HIGH confidence. |
| SwiftUI `@Observable` | Swift 5.9+ / built-in | Share screen state management | Existing app uses `@Observable` throughout (`NotesEngine`, `AppCoordinator`). Consistent pattern for `SlackShareViewModel`. HIGH confidence. |
| macOS `NSPasteboard` | AppKit / built-in | Copy-to-clipboard fallback | Native API for writing formatted text or plain text to clipboard on macOS. No alternatives needed. HIGH confidence. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| None required | — | Slack integration | Slack webhook = HTTP POST to a URL with JSON body. URLSession handles this without any Slack SDK. Introducing a Slack Swift SDK would add a dependency for trivial functionality. |
| None required | — | Markdown rendering in share preview | SwiftUI's `Text` with AttributedString can render basic markdown. For the post-meeting share screen preview, plain attributed string rendering is sufficient. Only add a third-party renderer if rich code block or table rendering is needed — unlikely for meeting summaries. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Slack Block Kit Builder (web tool) | Visual composition of Block Kit payloads | Use at https://app.slack.com/block-kit-builder to prototype and verify JSON before hardcoding payload structs. No installation needed. |
| Postman / curl | Webhook endpoint validation | Test the `SlackWebhookClient` against a real webhook URL before building UI. Verify Block Kit renders correctly in Slack. |

---

## Installation

No new Swift Package Manager dependencies required for this milestone.

All network, JSON, clipboard, and UI capabilities come from Foundation, AppKit, and SwiftUI — already in the project.

---

## Slack Integration: Architecture Decision

### Webhook vs. Bot API

The project decision (from PROJECT.md) is **incoming webhooks, no OAuth**. Research confirms this is the right call for a personal tool.

**Webhook approach (chosen):**
- User creates a Slack app in their workspace, enables "Incoming Webhooks", adds one webhook per channel
- Each webhook URL is a self-contained credential — paste into app settings and it works
- No OAuth flow, no token refresh, no Slack app review
- One webhook URL = one channel (this is the key constraint — see "What NOT to Use" below)
- Slack documents this as fully supported for modern Slack apps (not legacy deprecated integration)
- `POST https://hooks.slack.com/services/...` with `{"blocks": [...]}` — plain HTTP

**Multi-channel strategy:**
Because each webhook is locked to one channel, the "channel picker" in the share screen cannot be a free-form dropdown of workspace channels. It must be a **saved webhook list** — the user adds named webhooks (e.g., "engineering-standups", "product-team") in settings, and the share screen lets them pick from that list. This is the correct design for webhook-based delivery. MEDIUM confidence on whether this UX is well-known — it's a documented Slack limitation.

**Why not `chat.postMessage` Bot API:**
Would require OAuth app install, bot token, bot invited to each channel, token storage. Over-engineered for a personal tool. Breaks the "user pastes webhook URL" simplicity goal.

---

## Structured Summary Generation: Architecture Decision

### Output Format

**Recommended:** Non-streaming LLM call with structured JSON output.

The existing `NotesEngine` streams markdown — good for live display. Summaries are post-meeting, so streaming is less valuable. A single non-streaming call returning structured JSON is more reliable to parse into a typed `MeetingSummary` model.

**Payload schema (extend `OpenRouterClient`):**

```swift
struct MeetingSummary: Codable, Sendable {
    let title: String
    let keyDecisions: [String]
    let actionItems: [ActionItem]
    let discussionPoints: [String]
    let openQuestions: [String]

    struct ActionItem: Codable, Sendable {
        let task: String
        let owner: String?
    }
}
```

Use `response_format: { type: "json_schema", json_schema: { ... } }` in the request body. OpenRouter supports this on supported models. HIGH confidence (verified at openrouter.ai/docs/guides/features/structured-outputs).

**Ollama caveat:** Ollama uses a different `format` parameter (not wrapped in `response_format`) for structured output. As of March 2025, a GitHub issue (#10001) confirms Ollama ignores OpenAI-style `response_format.type = json_schema`. Mitigation: detect Ollama provider in `NotesEngine` / new `SummaryEngine` and send the `format` field directly instead. MEDIUM confidence — may be resolved in newer Ollama versions, worth checking at runtime.

**Fallback:** If structured JSON fails (local model doesn't support it, or JSON is malformed), fall back to markdown parsing — the existing `MarkdownMeetingWriter.extractLLMSections()` already parses `## Summary`, `## Action Items`, `## Decisions` sections from freeform LLM markdown. Use this as the graceful degradation path.

### Prompt Strategy

Extend or replace `MeetingTemplate.systemPrompt` with a summary-specific system prompt:

```
You are a meeting analyst. Given a meeting transcript, extract a structured summary.
Return ONLY valid JSON matching this schema — no prose, no markdown fences.

Schema: { title, keyDecisions, actionItems: [{task, owner}], discussionPoints, openQuestions }

Rules:
- title: 3-8 words, present tense noun phrase ("API Migration Planning")
- keyDecisions: decisions that were explicitly made, not discussed
- actionItems: concrete next steps with an owner if mentioned
- discussionPoints: major topics covered
- openQuestions: unresolved questions or items deferred
- Use "Unknown" for owner if not stated
```

**Why JSON not markdown for summaries:** The Slack share screen needs to render sections independently (decisions in one block, action items in another). Parsing markdown sections is fragile. Typed JSON maps directly to Block Kit section blocks.

---

## Slack Block Kit Payload Structure

### Recommended message layout for meeting summaries

```swift
// Block Kit payload: header + metadata + decisions + action items + questions
// POST body: {"blocks": [...]}
// Content-Type: application/json

// Block sequence:
// 1. header block: meeting title
// 2. context block: date + duration
// 3. divider
// 4. section: "*Key Decisions*\n• ..."  (mrkdwn)
// 5. section: "*Action Items*\n• ..."   (mrkdwn)
// 6. section: "*Open Questions*\n• ..." (mrkdwn, omit if empty)
```

Block Kit supports up to 50 blocks per message. Limit to 3-4 sections for readability. Use `mrkdwn` type (Slack's subset of markdown: `*bold*`, `_italic_`, bullet `•`, `\n` for newlines).

**Hardcoded URL pattern:** `https://hooks.slack.com/services/T.../B.../...`

Validation: reject stored webhooks that don't start with `https://hooks.slack.com/services/` to prevent accidental misconfiguration.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| URLSession for webhook POST | SlackKit (GitHub: SlackKit/SlackKit) | Never for this use case — SlackKit is unmaintained (last commit 2022), adds 50+ files for a 10-line HTTP call |
| JSON structured output + fallback markdown parse | Streaming markdown (like NotesEngine) | Use streaming markdown only if displaying summary live during generation is a UX requirement |
| Per-webhook saved list (channel picker) | chat.postMessage + OAuth bot token | Only if the user needs to post to channels they can't predict in advance, or needs to post to 10+ channels |
| Swift Codable structs for Block Kit | String interpolation / template strings | Never — string interpolation breaks JSON on special characters (quotes, unicode); Codable is safe |
| `@Observable` ViewModel for share screen | Direct state in View | Never — share screen has async send state (sending/sent/error) that needs observation |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Legacy Slack "Incoming WebHooks" app (marketplace app A0F7XDUAZ) | This is the deprecated custom integration, not a modern Slack app webhook. Slack's own docs classify it as legacy and warn it may be removed. | Create a new Slack App in api.slack.com with Incoming Webhooks enabled — this produces a modern, supported webhook URL with the same `hooks.slack.com` format |
| SlackKit / slack-swift SDKs | Unmaintained (SlackKit last updated 2022). Adds large dependency for a trivial use case. | URLSession + Codable |
| SwiftBlocksUI | Server-side Slack app framework, not relevant for outbound webhook posting from a macOS client | URLSession + Block Kit JSON |
| `response_format` structured JSON on Ollama with OpenAI syntax | Ollama silently ignores `response_format.type = json_schema` (GitHub issue #10001, March 2025) | Use Ollama's `format` field directly, or fall back to markdown parsing |
| Full OAuth flow for Slack | Requires Slack app review for public distribution, persistent token storage, refresh logic | Incoming webhooks — no token, no OAuth, no review |
| Sending raw markdown to Slack | Slack uses `mrkdwn` (subset), not standard CommonMark — headings, tables, fenced code blocks are not supported | Use Block Kit `section` blocks with `mrkdwn` text for supported formatting |

---

## Stack Patterns by Variant

**If OpenRouter is the LLM provider:**
- Use `response_format: { type: "json_schema", json_schema: { name: "MeetingSummary", strict: true, schema: {...} } }` in the request body
- Verified supported at openrouter.ai/docs/guides/features/structured-outputs
- Set `require_parameters: true` in provider preferences to ensure only models supporting structured output are selected

**If Ollama is the LLM provider:**
- Send `format: { <json schema> }` as a top-level field in the request body (not wrapped in `response_format`)
- Ollama v0.5+ supports this natively using GBNF grammar constraints
- If JSON parse still fails, fall back to `extractLLMSections()` markdown parsing

**If MLX or OpenAI-compatible is the LLM provider:**
- Try OpenAI-style `response_format` first (most OpenAI-compatible servers implement it)
- Fall back to markdown parsing on JSON decode failure

**If user has multiple Slack channels:**
- Store multiple named webhook entries (name + URL pairs) in `AppSettings` using Keychain per URL
- Share screen shows a `Picker` or `List` of saved webhooks
- Default selection = last-used webhook (persist to `UserDefaults` by webhook name)

---

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|-----------------|-------|
| OpenRouter structured output | Swift 6.2, URLSession | Pass `response_format` as part of `ChatRequest` — add optional field to existing struct |
| Ollama structured output | macOS 15+, localhost | `format` field is top-level in the request, not nested. Ollama v0.5+ required. |
| Slack Block Kit | Any URLSession, macOS 15+ | No version constraints — pure HTTP POST to a stable URL |
| `NSPasteboard` | macOS 10.0+ | Stable API, no changes needed |

---

## Sources

- [OpenRouter Structured Outputs docs](https://openrouter.ai/docs/guides/features/structured-outputs) — verified `response_format` support, HIGH confidence
- [Ollama Structured Outputs docs](https://docs.ollama.com/capabilities/structured-outputs) — verified `format` field, HIGH confidence
- [Ollama GitHub issue #10001](https://github.com/ollama/ollama/issues/10001) — documents OpenAI `response_format` incompatibility, MEDIUM confidence (may be patched in newer versions)
- [Slack Incoming Webhooks (modern)](https://docs.slack.dev/messaging/sending-messages-using-incoming-webhooks/) — verified still supported for modern Slack apps, HIGH confidence
- [Slack Block Kit reference](https://docs.slack.dev/block-kit/) — verified block types and mrkdwn support, HIGH confidence
- [Slack per-channel webhook blueprint](https://api.slack.com/best-practices/blueprints/per-channel-webhooks) — confirmed one webhook = one channel constraint, HIGH confidence
- [Slack chat.postMessage](https://api.slack.com/methods/chat.postMessage) — reviewed as alternative, confirmed requires bot token, HIGH confidence
- WebSearch: "Slack incoming webhooks modern app 2025" — MEDIUM confidence (multiple sources agree legacy vs modern distinction)

---

*Stack research for: MeetingScribe macOS — summary generation + Slack integration milestone*
*Researched: 2026-03-21*
