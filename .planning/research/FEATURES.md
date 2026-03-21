# Feature Research

**Domain:** Meeting transcription + auto-summary + Slack sharing (macOS, personal tool)
**Researched:** 2026-03-21
**Confidence:** HIGH (multiple sources, cross-verified against competitor landscape)

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist in any meeting summary tool. Missing these = product feels broken or incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Structured summary sections | Every competitor (Otter, Fireflies, Fathom) produces key decisions, action items, discussion points, open questions — this is the minimum viable output users expect | MEDIUM | NotesEngine already exists in codebase; extend with structured JSON schema targeting these four sections |
| Action items with owners | Users distinguish between "a summary" and "useful output" based on whether tasks are assigned — vague "next steps" lists are actively complained about | MEDIUM | LLM prompt must extract owner names from transcript context; structured JSON output via OpenRouter |
| Copy-to-clipboard export | Users need fallback if no webhook configured — clipboard is zero-friction sharing | LOW | Single button, plain text or Markdown format; no dependencies |
| Summary available immediately after session | Fathom delivers summaries before the meeting ends; delays erode trust in the tool | LOW | Trigger summary generation on session end event in AppCoordinator; streaming LLM response shows progress |
| Readable Slack message format | Users who share to Slack expect scannable output — not a wall of text dumped into a channel | MEDIUM | Use Slack Block Kit with header + section blocks; always include top-level text fallback for notifications |
| Solo / in-person recording mode | Mic-only recording for face-to-face meetings and voice memos is expected by users who take the tool off-desk | LOW | Reuse MicCapture; skip SystemAudioCapture; manual start via menu bar; no new audio stack needed |
| Session history / transcript access | Users expect to find previous meeting transcripts — "searchable record" is a core promise | LOW | Already exists via TranscriptLogger; no new work; surface in UI |

### Differentiators (Competitive Advantage)

Features not universally expected, but create meaningful advantage for this specific use case.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Recurring meeting channel memory | Most tools require manual channel selection every time; auto-populating the last-used Slack channel for the same meeting type removes the #1 friction point in post-meeting sharing | LOW | Store channel-per-meeting-app (Zoom/Teams/Meet) or by detected meeting title pattern; UserDefaults or simple JSON file sufficient |
| Post-meeting review screen before send | Competitors like Fireflies auto-fire to Slack; users want to review and optionally edit the summary before it lands in a channel | MEDIUM | SwiftUI sheet or window: show summary sections, channel picker, send/copy buttons; user owns the send decision |
| Local LLM support for privacy-sensitive meetings | No competitor offers offline summary generation; users with confidential meetings (legal, HR, board) can use Ollama instead of cloud LLM | LOW | Already supported via existing multi-provider architecture; surface in settings as "Summary model" selector |
| Webhook-based Slack (no OAuth app install) | Fireflies and Read.ai require OAuth app installation and workspace admin approval; webhook is self-service — user pastes one URL and it works | LOW | POST JSON payload to webhook URL; no Slack app approval required; user friction near zero |
| Clean Slack Block Kit formatting | Many tools dump plain-text walls into Slack; structured Block Kit with header, decision bullets, action item list, and open questions makes the post scannable | MEDIUM | Requires learning Block Kit JSON structure; not hard but needs implementation; 3000 char limit per text field to respect |
| Meeting type context in summary prompt | Standup vs. client call vs. planning session have different useful summary structures; a one-size prompt produces mediocre output for all of them | MEDIUM | Auto-detect meeting type from app (Zoom = call, no app detected = in-person); adjust system prompt accordingly |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Auto-send to Slack without review | Reduces friction, "just works" | A bad or incomplete summary gets broadcast to the team before the user can correct it; destroys trust in the tool after one incident | Post-meeting review screen with one-click send; reviewed output lands cleaner and users feel in control |
| Calendar integration for meeting detection | Seems smart — know what meeting is happening from calendar context | Requires calendar permissions, significant implementation complexity, and doesn't add much over existing app-launch detection; scope risk is high | Keep existing app-launch detection (Zoom/Teams/Meet process monitoring); it covers 95% of use cases |
| Always-on listening / ambient mode | Captures everything without user action | Privacy nightmare, battery drain, macOS microphone permission complexity; users would never trust an always-on app | Manual start via menu bar; low friction, user stays in control |
| Slack OAuth bot / full app integration | Seems more "official" than webhooks | Requires Slack app review, workspace admin approval, token management, refresh logic; prohibitive for a personal macOS tool | Incoming webhook — self-service, no admin approval, user pastes one URL; covers all real-world needs |
| Real-time summary during meeting | Show live summary as meeting progresses | Adds visual complexity during the meeting when user is trying to focus; competes with real-time transcript display | Post-meeting only; transcript is the real-time artifact, summary is the post-meeting artifact |
| Multi-workspace Slack support | Power users have multiple Slack orgs | Adds significant UI complexity (workspace switcher, multiple webhook stores, per-workspace channel memory) for a personal tool; most users have one workspace | Single webhook URL in settings; if user needs another workspace they change the URL; simple and correct |
| Speaker-attributed action items in Slack | "John said he'd do X" in the Slack post | Requires reliable speaker diarization with real names (not "Speaker 1"); existing system uses you/them labels, not names; promises more than it can deliver | Attribute by role context ("Host committed to…") or leave unattributed; don't promise names you can't guarantee |
| Knowledge base / real-time note surfacing | Surface relevant past notes during meeting | Already scoped out; adds significant complexity to what is a focused transcript→summary→share tool | Stripped from codebase per PROJECT.md |

## Feature Dependencies

```
Solo mode (mic-only)
    └── requires ──> Manual start control (menu bar)
                        (already exists in base app)

Auto-summary on session end
    └── requires ──> Session end event in AppCoordinator
    └── requires ──> LLM provider configured (OpenRouter or Ollama)
    └── requires ──> Structured summary prompt + schema

Post-meeting review screen
    └── requires ──> Auto-summary (must have output to display)
    └── requires ──> Slack webhook URL configured in settings

Slack send
    └── requires ──> Post-meeting review screen (user confirms)
    └── requires ──> Slack webhook URL in settings
    └── requires ──> Block Kit message formatter

Recurring channel memory
    └── enhances ──> Post-meeting review screen (auto-populates channel picker)
    └── depends on ──> Channel picker having been used at least once

Copy-to-clipboard
    └── enhances ──> Post-meeting review screen (alternative to Slack send)
    └── independent of ──> Slack webhook (works with no webhook configured)

Meeting type context in summary prompt
    └── enhances ──> Auto-summary (better output quality)
    └── depends on ──> Existing meeting app detection (Zoom/Teams/Meet)
```

### Dependency Notes

- **Auto-summary requires LLM configured:** If no API key or Ollama running, summary generation fails silently — must handle gracefully with a clear error in the review screen rather than a crash.
- **Post-meeting review screen is the hub:** Slack send, copy-to-clipboard, and channel memory all flow through this single screen. Build it as a coherent unit, not piecemeal.
- **Solo mode is independent:** It shares the MicCapture stack but doesn't depend on any of the summary/Slack features — it just feeds a transcript that the summary pipeline then consumes.
- **Copy-to-clipboard is a fallback, not a duplicate:** Users without a webhook configured still get value; clipboard is the zero-config path.

## MVP Definition

### Launch With (v1 — this milestone)

Minimum set to deliver the core value: "every meeting produces a clear, shareable record."

- [ ] Solo mode (mic-only, manual start) — unlocks in-person use and voice memos
- [ ] Auto-generated structured summary on session end (key decisions, action items, discussion points, open questions)
- [ ] Post-meeting review screen showing summary before any sharing action
- [ ] Copy-to-clipboard from review screen — zero-config sharing fallback
- [ ] Slack webhook send from review screen with channel picker
- [ ] Slack Block Kit formatted message (header + sections, not a text wall)
- [ ] Strip knowledge base UI and code

### Add After Validation (v1.x)

Features to add once the core flow is confirmed working and trusted.

- [ ] Recurring meeting channel memory — add once users have gone through the flow a few times and the channel picker UX is validated
- [ ] Meeting type context in summary prompt — refine after seeing real summary output quality from v1 prompt

### Future Consideration (v2+)

Features to defer until there is clear user demand.

- [ ] Summary template customization (e.g., user-defined sections) — only if users find the four default sections insufficient
- [ ] Multiple Slack webhook profiles — only if users demonstrably work across multiple workspaces regularly
- [ ] Summary search across sessions — only after transcript history usage patterns are understood

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Auto-summary (structured, 4 sections) | HIGH | MEDIUM | P1 |
| Post-meeting review screen | HIGH | MEDIUM | P1 |
| Solo mode (mic-only) | HIGH | LOW | P1 |
| Copy-to-clipboard | HIGH | LOW | P1 |
| Slack Block Kit send | HIGH | MEDIUM | P1 |
| Strip knowledge base | MEDIUM | LOW | P1 |
| Recurring channel memory | MEDIUM | LOW | P2 |
| Meeting type context in prompt | MEDIUM | LOW | P2 |
| Summary template customization | LOW | HIGH | P3 |
| Multi-workspace Slack | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | Fireflies | Fathom | Otter | Our Approach |
|---------|-----------|--------|-------|--------------|
| Structured summary | Yes (decisions, actions, notes) | Yes (fastest delivery, best action attribution) | Yes (~95% accuracy, robust multi-speaker) | Yes — 4 sections via structured LLM JSON |
| Slack integration | OAuth + channel picker, auto-fires | OAuth | OAuth | Webhook-only, user reviews before send |
| In-person / solo mode | Mobile app required | Zoom-only | Mobile app | Native macOS mic-only mode, no phone needed |
| Local/private LLM | No | No | No | Yes — Ollama support via existing architecture |
| Review before sharing | No (auto-fire) | No (auto-fire) | No (auto-fire) | Yes — deliberate UX differentiator |
| No admin approval needed | No (OAuth) | No (OAuth) | No (OAuth) | Yes — webhook is self-service |

## Sources

- [Top 10 AI notetakers in 2026 — AssemblyAI](https://www.assemblyai.com/blog/top-ai-notetakers) — MEDIUM confidence (editorial review)
- [Otter vs Fireflies vs Fathom comparison — index.dev](https://www.index.dev/blog/otter-vs-fireflies-vs-fathom-ai-meeting-notes-comparison) — MEDIUM confidence
- [Fireflies Slack integration docs](https://fireflies.ai/blog/fireflies-slack-integration/) — HIGH confidence (official product docs)
- [Slack Block Kit official docs](https://docs.slack.dev/block-kit/) — HIGH confidence (official)
- [Slack incoming webhooks official docs](https://docs.slack.dev/messaging/sending-messages-using-incoming-webhooks/) — HIGH confidence (official)
- [Fellow.ai meeting summary guide](https://fellow.ai/blog/how-to-write-a-meeting-summary-with-examples/) — MEDIUM confidence
- [Best AI meeting summary tools 2026 — meetingnotes.com](https://meetingnotes.com/blog/best-ai-meeting-summary-tool) — MEDIUM confidence
- [Best AI note takers for in-person meetings — plaud.ai](https://www.plaud.ai/blogs/articles/the-7-best-ai-note-taker-for-in-person-meetings-plus-buying-guide) — LOW confidence (vendor source)

---
*Feature research for: MeetingScribe (OpenOats fork) — meeting summary + Slack sharing milestone*
*Researched: 2026-03-21*
