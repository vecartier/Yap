# Pitfalls Research

**Domain:** macOS meeting transcription app — adding auto-summary, solo mode, and Slack integration to an existing Swift 6.2 codebase (OpenOats fork)
**Researched:** 2026-03-21
**Confidence:** HIGH (codebase read directly; external claims verified against official Slack docs and OpenRouter docs)

---

## Critical Pitfalls

### Pitfall 1: Slack Webhook Is Channel-Locked — "Channel Picker" UX Will Not Work As Expected

**What goes wrong:**
The PROJECT.md specifies a "post-meeting share screen with channel picker" and "recurring meeting channel memory (auto-populate last-used channel)." Modern Slack incoming webhooks are permanently bound to the channel selected when the webhook was created in the Slack app UI. You cannot override the destination channel at send time in the JSON payload — the `channel` field in Block Kit messages sent via webhook is ignored. A "channel picker" that lets users select from a list of channels and routes accordingly is not achievable with a single webhook URL.

**Why it happens:**
Developers assume Slack webhooks behave like the `chat.postMessage` bot API, where the `channel` parameter in the payload controls destination. Slack intentionally locked this down in 2018 when they deprecated legacy custom integrations.

**How to avoid:**
Re-scope the "channel picker" to a "webhook picker." The user configures one or more named webhooks in Settings (e.g., "#engineering" → webhook URL A, "#product" → webhook URL B). The share screen lets them pick which named webhook to send to. Store the last-used webhook URL per meeting app (e.g., last Zoom webhook, last solo webhook) as the "channel memory." This matches the PROJECT.md intent without requiring the impossible.

**Warning signs:**
- Any design that includes a free-text channel name field (like "#engineering") without a corresponding webhook URL field
- Code that constructs a JSON payload with `"channel": "#something"` for webhook delivery
- UI mockups showing a dynamic channel list populated from Slack's API

**Phase to address:**
Settings/Slack integration phase — define the data model for named webhook configurations before building any share UI.

---

### Pitfall 2: Transcript Truncation Silently Discards the Middle of the Meeting

**What goes wrong:**
`NotesEngine.formatTranscript()` already implements a truncation strategy at 60,000 characters: it keeps the first 1/3 and last 1/3 of utterances, discarding the middle. For a 90-minute meeting this typically means 20-40 minutes of discussion — often the most substantive portion — is silently omitted from the summary. The LLM will not flag the gap. Action items and decisions from the middle are lost without any user-visible warning.

**Why it happens:**
The existing truncation was designed for notes generation where the model streams a response and token cost is variable. Extending this unchanged for structured summaries produces the same silent failure. The `maxChars = 60_000` constant is not surfaced anywhere in the UI.

**How to avoid:**
For structured summaries, switch from character-count truncation to token-aware chunking with explicit user notification:
1. If the transcript exceeds the model's practical context window (~80K tokens for most OpenRouter models, ~8K for local Ollama), surface a warning in the share screen ("Long meeting: middle section summarized separately").
2. For Ollama/MLX local models with small context windows (~4K–8K tokens), implement a map-reduce approach: summarize in segments, then summarize the segment summaries.
3. Never silently discard content — show a character/token count or a "meeting was long — summary covers highlights" disclaimer.

**Warning signs:**
- Summary generation that reuses `NotesEngine.formatTranscript()` unchanged for a new `SummaryEngine`
- No token or character count visible to the user before or after summary generation
- Long meetings (>60 min) consistently produce summaries missing decisions made mid-call

**Phase to address:**
Summary generation phase — design the transcript→prompt pipeline before writing the LLM call. Add a meeting length heuristic check that selects the right summarization strategy.

---

### Pitfall 3: LLM Summary Presents Hallucinated Action Items as Fact

**What goes wrong:**
Meeting summary LLMs are trained to generate "helpful-sounding" outputs. When the transcript is ambiguous — someone said "we should look into X" — the model may emit "Action item: [Name] to research X by [date]" including a fabricated name and deadline that never appeared in the transcript. These look authoritative in the Slack message. Research from ACM (2025) found off-the-shelf summarization tools capture only 22% of explicitly stated commitments and produce 14% false positive action items.

**Why it happens:**
The existing `NotesEngine` uses a single streaming prompt with a freeform markdown template. The model fills in structural slots (action items, decisions) even when evidence is thin. This is an LLM optimization-for-probability problem, not a prompt length problem.

**How to avoid:**
Use a two-phase structured prompt strategy:
1. Phase 1: "Extract only statements from the transcript that are explicit commitments, decisions, or questions. Quote the exact transcript text." (grounding pass)
2. Phase 2: "Format the following extracted statements as a structured summary." (formatting pass)

This chains two non-streaming `complete()` calls (already available in `OpenRouterClient`) rather than a single streaming call. The grounding pass dramatically reduces hallucination by forcing the model to cite evidence before summarizing it.

Additionally, include a disclaimer in the share screen: "Review before sending — AI summaries can miss context or misattribute ownership."

**Warning signs:**
- Summary contains specific names and deadlines that seem oddly precise for a casual discussion
- Users report receiving Slack messages where they "owned" action items they don't remember agreeing to
- Prompt structure sends the full transcript directly to a formatting instruction in a single message

**Phase to address:**
Summary generation phase — the prompt architecture decision must be made before implementing `SummaryEngine`. Do not reuse `NotesEngine.generate()` verbatim for summaries.

---

### Pitfall 4: Solo Mode Breaks the Existing Session Lifecycle Silently

**What goes wrong:**
`AppCoordinator.startTranscription()` calls `await transcriptionEngine?.start()` which internally initializes both `MicCapture` and `SystemAudioCapture`. For solo mode (mic-only), `SystemAudioCapture` should be skipped entirely — but if the code path is not explicitly separated, `SystemAudioCapture` will attempt `AudioHardwareCreateProcessTap()`, which may fail silently on machines without a running audio output process, or worse, succeed and capture silence, creating an empty second audio stream that pollutes the transcript merge logic.

**Why it happens:**
The existing `TranscriptionEngine` was designed with the dual-stream assumption baked in. It is tempting to just pass a flag and skip the system audio capture, but the aggregate device creation and IOProc registration in `SystemAudioCapture` run regardless of whether audio data ever arrives.

**How to avoid:**
Create a concrete separation: `MeetingMode.solo` vs `MeetingMode.call`. At session start, `AppCoordinator` should instantiate a `TranscriptionEngine` configured for the mode, not add a runtime skip flag. The simplest approach is a factory method on `TranscriptionEngine` or a separate `SoloTranscriptionEngine` subtype that only initializes `MicCapture`. This avoids patching `SystemAudioCapture`'s teardown path.

**Warning signs:**
- `TranscriptionEngine.start()` receives a `skipSystemAudio: Bool` parameter
- `SystemAudioCapture.bufferStream()` is called then immediately cancelled in solo mode
- Transcript lines in solo sessions contain unexpected "Them:" utterances (echo of mic into system audio path)

**Phase to address:**
Solo mode phase — the engine initialization architecture must be settled first, before wiring up the menu bar toggle.

---

### Pitfall 5: Slack Webhook URL Stored in UserDefaults (Plain Text Secret Leak)

**What goes wrong:**
Webhook URLs are effectively secrets — anyone who has the URL can post to that Slack channel on behalf of the workspace. Storing them in `UserDefaults` (backed by a plain `.plist` in `~/Library/Preferences/`) means the URL is visible to any app on the machine that reads preferences, shows up in backup files without encryption, and appears in crash reports if the settings object is dumped.

**Why it happens:**
The existing codebase already handles API keys correctly via macOS Keychain (verified in `AppSettings.swift` which uses `Security` framework). The instinct to store webhook URLs in `AppSettings` alongside non-secret preferences (model selection, locale) is natural but wrong for secrets.

**How to avoid:**
Store webhook URLs in the macOS Keychain alongside the existing OpenRouter API key, using a service identifier like `com.meetingscribe.slack-webhook`. The existing Keychain access pattern in `AppSettings.swift` should be reused directly. `UserDefaults` may store a display label ("My team channel") but not the URL itself.

**Warning signs:**
- Webhook URLs stored with `@AppStorage` or directly in `UserDefaults.standard.set()`
- Webhook URL visible when running `defaults read` in Terminal
- Settings serialized with `Codable` that includes the webhook URL as a plain string field

**Phase to address:**
Settings/Slack integration phase — establish the Keychain storage pattern for webhook URLs before the share UI is wired.

---

### Pitfall 6: Post-Meeting Share Screen Blocks the `finalizeCurrentSession` Pipeline

**What goes wrong:**
`AppCoordinator.finalizeCurrentSession()` is an async chain: drain audio → drain refinements → drain JSONL writes → backfill refined text → write sidecar → close files → encode audio. The summary generation needs the fully drained transcript, so it must happen after step 3 (drain JSONL). If the share screen is shown too early — before finalization completes — the summary will be generated from a partial transcript missing the last few utterances. In worst case with a 30-second finalization timeout, the share screen may show a loading state for 30+ seconds with no feedback.

**Why it happens:**
The `finalizationComplete` event already triggers `lastEndedSession` to populate, which the UI watches. If summary generation is kicked off at `finalizationComplete`, the timing is correct. But it is tempting to start streaming the summary as soon as the user taps "Stop" — before finalization completes — to appear fast.

**How to avoid:**
Summary generation must be triggered from within `finalizeCurrentSession()` after step 3 (after `sessionStore.awaitPendingWrites()`), not as a reaction to `lastEndedSession` in the UI layer. This ensures the full transcript is available. The share screen should show a "Generating summary…" state tied to summary completion, not to session end. Use a separate `@Observable` summary state on `AppCoordinator` (similar to `NotesEngine.isGenerating`) that drives the share screen's loading indicator.

**Warning signs:**
- Summary generation starts in a `onChange(of: coordinator.lastEndedSession)` view modifier
- Summary result misses the last 2-5 lines of what was said
- The share screen appears instantly after stopping with a very short summary on long meetings

**Phase to address:**
Summary generation phase — the hook point into `AppCoordinator.finalizeCurrentSession()` must be designed explicitly, not bolted on after the share screen is built.

---

### Pitfall 7: Slack Block Kit Character Limits Silently Truncate the Summary

**What goes wrong:**
A Slack section block accepts a maximum of 3,000 characters. A single markdown block is capped at 12,000 characters. The total payload cap before Slack returns HTTP 400 is approximately 40,000 characters. Meeting summaries that include a full discussion section plus action items plus decisions can easily exceed 3,000 characters for a 60-minute meeting. Slack silently truncates at the block level — the message sends successfully (HTTP 200) but the posted message is cut off mid-sentence.

**Why it happens:**
Developers test with short summaries from brief meetings and never hit the limit. The 200 OK response masks the truncation entirely — there is no error in the response body.

**How to avoid:**
Split the Slack message into multiple blocks: one section block per summary category (Decisions, Action Items, Key Points, Open Questions), each independently capped at 3,000 characters. If any single category exceeds 3,000 characters, truncate with "… see full notes in transcript" and a fallback note. Test with a 90-minute meeting transcript before shipping.

**Warning signs:**
- The Slack formatter puts the entire summary into a single `section` block with `type: "mrkdwn"`
- No character count check before constructing the Block Kit payload
- Slack messages from long meetings are cut off mid-action-item

**Phase to address:**
Slack formatting phase — the Block Kit formatter must enforce per-block limits before the first integration test.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Reuse `NotesEngine.generate()` for summaries by adding a new template | Zero new code | Template conflation — notes and summaries diverge in structure; one prompt cannot serve both well | Never — create `SummaryEngine` as a separate type |
| Store all Slack config in `AppSettings` `Codable` struct | Simple persistence | Webhook URL leaks into preferences plist | Never — use Keychain for URLs |
| Trigger summary from UI `onChange` of `lastEndedSession` | Simple wiring | Race: summary runs against partial transcript | Only for prototyping; must be fixed before first real use |
| Single webhook URL in settings (no multi-webhook support) | Simpler settings UI | Channel picker UX goal is permanently blocked | Acceptable for MVP if "channel picker" is reframed as "webhook picker" |
| Skip system audio capture with a bool flag in existing `TranscriptionEngine` | Minimal code change | Aggregate device and IOProc lifecycle still runs; audio engine teardown path has subtle bugs | Never — use mode-specific initialization |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Slack Incoming Webhook | Sending `channel` field in payload to override destination | Webhooks ignore the `channel` field entirely; destination is fixed at webhook creation time |
| Slack Incoming Webhook | Assuming HTTP 200 means the message was fully displayed | HTTP 200 confirms delivery receipt, not display completeness; truncated blocks still return 200 |
| Slack Block Kit | Putting entire summary in one `section` block | Split by summary category; enforce 3,000-char limit per section block |
| OpenRouter structured output | Using `stream: true` with `response_format` for JSON schema | Response Healing (OpenRouter's JSON repair) only works for non-streaming requests; use `complete()` not `streamCompletion()` for structured summary JSON |
| Ollama local model | Sending full transcript to a model with 4K–8K context window | Local models (Ollama/MLX) often have small context windows; the 60K-char transcript will be truncated by the model itself without error — test with real meeting lengths |
| macOS Keychain | Reading Keychain in a Swift 6.2 actor without proper isolation | Keychain reads are synchronous blocking calls; wrap in `Task { }` or use `nonisolated` access pattern matching the existing `AppSettings` Keychain implementation |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Streaming summary generation blocks `@MainActor` for token updates | UI freezes during summary generation; menu bar popover becomes unresponsive | Summary token updates must be yielded via continuation on background task, published to `@MainActor` via `withMutation` pattern already used in `NotesEngine` | Immediately on first real use with a streaming model |
| Non-streaming two-phase summary (grounding + format) with local Ollama | 60–120 second wait with no UI feedback | Show per-phase progress indicator; run both phases in a single `Task` with intermediate state updates | For meetings >30 min with local Ollama models |
| `URLSession.shared` for Slack webhook POST from `@MainActor` | Warning in Swift 6.2: Sendability of URLSession from MainActor | Use `URLSession.shared.data(for:)` from a `Task { }` not directly on `@MainActor`; pattern is already correct in `OpenRouterClient` (actor-isolated) | Build warnings in Swift 6.2 strict concurrency mode |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Slack webhook URL in `UserDefaults` or Codable `AppSettings` | Any local process or backup can read the URL; URL in crash reports | Store in macOS Keychain with same pattern as OpenRouter API key in `AppSettings.swift` |
| Logging the webhook URL in `os.Logger` for debugging | URL appears in Console.app and system logs; visible to other apps | Never log the URL; log only the host portion (e.g., `hooks.slack.com`) and HTTP response code |
| Sending transcript text to Slack (not just summary) | Raw audio transcript contains PII (names, medical info, financials) in meetings | Only the LLM-generated summary goes to Slack, never raw transcript lines — enforce this at the formatter layer |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Share screen appears with no loading state while summary is generating | User sees blank summary; unclear if it failed or is loading | Show skeleton/spinner tied to `SummaryEngine.isGenerating`; disable Send button until ready |
| "Send to Slack" fires immediately on share screen open with no review step | User sends a hallucinated or incorrect summary before reading it | Summary is always shown in full before the Send button is enabled; no auto-send on session end |
| Single "Send" button with no confirmation for first-time webhook send | User accidentally sends to wrong channel (wrong webhook selected) | Show the webhook display name ("My team channel") prominently in the share screen; first send to a new webhook shows a confirmation alert |
| Share screen dismisses after Send with no success/failure feedback | User cannot tell if Slack delivery succeeded or silently failed | Show inline success state ("Sent to #engineering") or error state with retry button; HTTP errors from Slack must surface, not be swallowed |
| Solo mode recording indistinguishable from call mode in menu bar | User starts call mode for an in-person meeting; system audio capture runs for no reason | Menu bar recording indicator must label the mode: "Recording (solo)" vs "Recording (call)" |

---

## "Looks Done But Isn't" Checklist

- [ ] **Slack send:** Verify HTTP response code is 200 AND that the message appears in Slack with full content — a 200 with truncated display still looks done in code
- [ ] **Summary generation:** Test with a 90-minute meeting (generate a long synthetic transcript) — short test meetings never trigger the truncation pitfall
- [ ] **Solo mode:** Verify `SystemAudioCapture` is not initialized or registered at all — not just skipped after initialization — by checking that no aggregate CoreAudio device is created during a solo session
- [ ] **Webhook storage:** Run `defaults read` for the app's bundle ID and confirm webhook URLs do not appear — Keychain storage is correctly isolated
- [ ] **Finalization timing:** Log transcript line count at summary generation time and at session stop time — they must match; any difference indicates a race condition
- [ ] **Block Kit limits:** Send a Slack message from a 90-minute meeting and verify the posted message is complete, not cut off

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Channel-picker built before webhook model discovered | MEDIUM | Rename "channel picker" to "webhook picker" in UI; add URL field per entry; data model change is additive |
| Webhook URL leaked to UserDefaults in shipped build | HIGH | Force migration: read from UserDefaults, write to Keychain, delete from UserDefaults on next launch; notify users via release notes |
| Finalization race causing partial summaries | LOW | Add assertion in `SummaryEngine.generate()` that transcript count matches expected count from `sessionStore`; fix hook point in `finalizeCurrentSession()` |
| Block Kit truncation discovered post-ship | LOW | Add per-block character guard in the Slack formatter; redeploy; no user data at risk |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Webhook is channel-locked (Pitfall 1) | Slack integration phase — before share UI design | Data model includes per-webhook `(label, url)` pairs; no free-text channel field in UI |
| Transcript truncation loses middle (Pitfall 2) | Summary generation phase — transcript pipeline design | Test with synthetic 90-min transcript; assert all utterances are represented or a warning is shown |
| Hallucinated action items (Pitfall 3) | Summary generation phase — prompt architecture | Two-phase prompt implemented; grounding pass verified with a known transcript |
| Solo mode breaks session lifecycle (Pitfall 4) | Solo mode phase — engine initialization | No `AudioHardwareCreateProcessTap` call in solo session (verified via log search) |
| Webhook URL in UserDefaults (Pitfall 5) | Slack integration phase — settings persistence design | `defaults read` shows no URL; Keychain contains the URL |
| Share screen shown before finalization completes (Pitfall 6) | Summary generation phase — coordinator hook point | Transcript line count in summary equals transcript line count at session end |
| Block Kit truncation (Pitfall 7) | Slack formatting phase — Block Kit formatter implementation | 90-min meeting Slack message is complete; no mid-sentence cutoff |

---

## Sources

- [Slack Incoming Webhooks — Official Docs](https://docs.slack.dev/messaging/sending-messages-using-incoming-webhooks/) — channel locking behavior, payload format
- [Slack Block Kit Blocks Reference](https://docs.slack.dev/reference/block-kit/blocks/) — character limits per block type
- [Slack Changelog: Truncating Really Long Messages (2018)](https://api.slack.com/changelog/2018-04-truncating-really-long-messages) — 40K character limit origin
- [ACM PACMHCI: LLM-powered Meeting Recap System (2025)](https://dl.acm.org/doi/10.1145/3711074) — 22% action item capture rate, hallucination patterns
- [OpenRouter Structured Outputs Guide](https://openrouter.ai/docs/guides/features/structured-outputs) — Response Healing streaming limitation
- [OpenRouter Response Healing Announcement](https://openrouter.ai/announcements/response-healing-reduce-json-defects-by-80percent) — non-streaming only
- Codebase direct analysis: `NotesEngine.swift` (60K truncation strategy), `AppCoordinator.swift` (finalization pipeline), `OpenRouterClient.swift` (streaming vs non-streaming), `MicCapture.swift` (engine lifecycle), `SystemAudioCapture.swift` (process tap lifecycle), `AppSettings.swift` (Keychain pattern for API keys)

---
*Pitfalls research for: macOS meeting transcription — auto-summary, solo mode, Slack integration (OpenOats fork)*
*Researched: 2026-03-21*
