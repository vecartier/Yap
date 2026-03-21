# Requirements: MeetingScribe

**Defined:** 2026-03-21
**Core Value:** Every meeting produces a clear, shareable record without manual note-taking

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Solo Mode

- [ ] **SOLO-01**: User can start a mic-only recording session for in-person meetings via menu bar
- [ ] **SOLO-02**: User can start a mic-only recording session for personal voice memos via menu bar
- [ ] **SOLO-03**: Solo mode produces a timestamped transcript identical in format to call transcripts
- [ ] **SOLO-04**: Solo mode uses single-speaker labeling (no "them" speaker)

### Cleanup

- [ ] **CLEAN-01**: Knowledge base feature (KB indexing, embedding, real-time suggestions) is removed from codebase
- [ ] **CLEAN-02**: KB-related UI elements are removed from settings and main views
- [ ] **CLEAN-03**: Voyage AI and Ollama embed client dependencies are removed if only used by KB

### Summary

- [ ] **SUMM-01**: Structured summary is auto-generated when a session ends
- [ ] **SUMM-02**: Summary includes key decisions extracted from transcript
- [ ] **SUMM-03**: Summary includes action items with owner attribution where identifiable
- [ ] **SUMM-04**: Summary includes main discussion points
- [ ] **SUMM-05**: Summary includes open questions / unresolved items
- [ ] **SUMM-06**: Summary uses two-phase LLM prompt (grounding pass then formatting) to minimize hallucination
- [ ] **SUMM-07**: Summary generation hooks into AppCoordinator after awaitPendingWrites(), not from UI
- [ ] **SUMM-08**: Summary works with both OpenRouter (cloud) and Ollama (local) providers
- [ ] **SUMM-09**: Summary is saved as Markdown alongside the transcript in ~/Documents/OpenOats/

### Slack Message

- [ ] **SLCK-01**: Summary is formatted as a Slack-ready message (Markdown with clear sections)
- [ ] **SLCK-02**: Slack message includes header, key decisions, action items, discussion points, open questions
- [ ] **SLCK-03**: Message is optimized for readability when pasted into Slack

### Share UI

- [ ] **SHARE-01**: Post-meeting share screen appears after summary generation
- [ ] **SHARE-02**: Share screen displays formatted summary (read-only)
- [ ] **SHARE-03**: Share screen has "Copy to Clipboard" button for Slack-formatted message
- [ ] **SHARE-04**: Share screen has "Save & Close" button
- [ ] **SHARE-05**: Share screen is a separate window (not crammed into menu bar popover)

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Slack Webhook Integration

- **SLCK2-01**: User can configure named Slack webhook URLs in settings
- **SLCK2-02**: Webhook URLs stored in macOS Keychain
- **SLCK2-03**: Slack Block Kit formatting for richer messages
- **SLCK2-04**: Send to Slack button in share screen
- **SLCK2-05**: Webhook picker remembers last-used webhook per meeting type

### Enhanced Sharing

- **SHARE2-01**: User can edit summary text before sending to Slack
- **SHARE2-02**: Meeting type context adjusts summary prompt (standup vs client call vs planning)
- **SHARE2-03**: Summary includes a confidence indicator per section

### Automation

- **AUTO-01**: Option to auto-send to default webhook without review screen
- **AUTO-02**: Slack thread replies for recurring meetings

## Out of Scope

| Feature | Reason |
|---------|--------|
| Knowledge base / note surfacing | Stripped to simplify — not core to transcript→summary→share |
| Always-on listening | Privacy risk, battery drain, manual start is sufficient |
| Calendar integration | App-launch detection covers 95% of cases, calendar adds scope risk |
| Slack OAuth bot | Webhook is self-service, no admin approval needed for personal tool |
| Speaker name diarization | System uses you/them, not real names — can't reliably promise named attribution |
| Multi-workspace Slack | Change webhook URL to switch; simple and correct for personal tool |
| Real-time summary during meeting | Transcript is the real-time artifact, summary is post-meeting |
| Mobile app | macOS only |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SOLO-01 | Phase 1 | Pending |
| SOLO-02 | Phase 1 | Pending |
| SOLO-03 | Phase 1 | Pending |
| SOLO-04 | Phase 1 | Pending |
| CLEAN-01 | Phase 1 | Pending |
| CLEAN-02 | Phase 1 | Pending |
| CLEAN-03 | Phase 1 | Pending |
| SUMM-01 | Phase 2 | Pending |
| SUMM-02 | Phase 2 | Pending |
| SUMM-03 | Phase 2 | Pending |
| SUMM-04 | Phase 2 | Pending |
| SUMM-05 | Phase 2 | Pending |
| SUMM-06 | Phase 2 | Pending |
| SUMM-07 | Phase 2 | Pending |
| SUMM-08 | Phase 2 | Pending |
| SUMM-09 | Phase 2 | Pending |
| SLCK-01 | Phase 3 | Pending |
| SLCK-02 | Phase 3 | Pending |
| SLCK-03 | Phase 3 | Pending |
| SHARE-01 | Phase 3 | Pending |
| SHARE-02 | Phase 3 | Pending |
| SHARE-03 | Phase 3 | Pending |
| SHARE-04 | Phase 3 | Pending |
| SHARE-05 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 24 total
- Mapped to phases: 24
- Unmapped: 0

---
*Requirements defined: 2026-03-21*
*Last updated: 2026-03-21 after roadmap creation*
