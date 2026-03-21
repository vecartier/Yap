# Roadmap: MeetingScribe

## Overview

Three phases transform the OpenOats fork into a focused transcript-to-summary-to-share tool. Phase 1 clears dead code and establishes the solo recording mode. Phase 2 builds the SummaryEngine — the core value of this milestone — hooked into the session lifecycle. Phase 3 delivers the post-meeting share screen and clipboard export, making every session's output immediately shareable to Slack.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Foundation** - Strip knowledge base, add solo/mic-only mode, establish MeetingMode enum
- [ ] **Phase 2: Summary Engine** - Auto-generate structured summaries on session end, save to disk
- [ ] **Phase 3: Share UI** - Post-meeting review screen with formatted summary and copy-to-clipboard export

## Phase Details

### Phase 1: Foundation
**Goal**: Codebase is clean and mic-only recording works for in-person meetings
**Depends on**: Nothing (first phase)
**Requirements**: SOLO-01, SOLO-02, SOLO-03, SOLO-04, CLEAN-01, CLEAN-02, CLEAN-03
**Success Criteria** (what must be TRUE):
  1. User can start a mic-only recording session from the menu bar without triggering system audio capture
  2. Solo mode transcript uses single-speaker labeling and is saved in the same format as call transcripts
  3. Knowledge base UI elements are absent from settings and main views
  4. VoyageAI and Ollama embed client code is removed from the codebase
**Plans**: 2 plans

Plans:
- [ ] 01-01-PLAN.md — Remove knowledge base feature (delete 6 files, scrub KB references from 6 source files)
- [ ] 01-02-PLAN.md — Add solo mode with MeetingMode enum, Speaker.room, mode-aware TranscriptionEngine, and three-button menu bar UI

### Phase 2: Summary Engine
**Goal**: Every session end automatically produces a structured, saved summary
**Depends on**: Phase 1
**Requirements**: SUMM-01, SUMM-02, SUMM-03, SUMM-04, SUMM-05, SUMM-06, SUMM-07, SUMM-08, SUMM-09
**Success Criteria** (what must be TRUE):
  1. A structured summary file appears in ~/Documents/OpenOats/ immediately after ending any meeting session
  2. Summary contains four clearly labeled sections: key decisions, action items, open questions, and discussion points
  3. Action items include owner attribution where the transcript contains identifiable owners
  4. Summary generation works with both OpenRouter (cloud) and Ollama (local) LLM providers
  5. Summary is triggered from AppCoordinator after transcript finalization, not from the UI layer
**Plans**: TBD

Plans:
- [ ] 02-01: Build SummaryEngine actor with two-phase prompt and provider branching
- [ ] 02-02: Hook SummaryEngine into AppCoordinator.finalizeCurrentSession() and save output to disk

### Phase 3: Share UI
**Goal**: Users can review their summary and copy a Slack-ready message in one step after every meeting
**Depends on**: Phase 2
**Requirements**: SLCK-01, SLCK-02, SLCK-03, SHARE-01, SHARE-02, SHARE-03, SHARE-04, SHARE-05
**Success Criteria** (what must be TRUE):
  1. A share window opens automatically after summary generation completes, showing the formatted summary
  2. User can copy a Slack-formatted message to clipboard with a single button click
  3. Slack message contains a header plus all four summary sections formatted for Slack Markdown
  4. User can dismiss the share window and the session is saved
**Plans**: TBD

Plans:
- [ ] 03-01: Build SlackFormatter and format MeetingSummary as Slack Markdown message
- [ ] 03-02: Build PostMeetingShareUI window with summary display, copy button, and save/close action

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 0/2 | Not started | - |
| 2. Summary Engine | 0/2 | Not started | - |
| 3. Share UI | 0/2 | Not started | - |
