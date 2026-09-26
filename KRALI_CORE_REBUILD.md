# KRALİ Core Rebuild

## Product contract

KRALİ is a conversational personal AI that can reason with the user, perform
evidence-backed public research, and prepare high-quality repository changes.
It does not claim to control the desktop, local files, or external software
unless a separately approved capability is installed.

Every request follows one small, inspectable loop:

```
conversation context
  -> intent contract
  -> chat | research | development
  -> evidence or candidate diff
  -> evaluation
  -> user approval when mutation is requested
```

## Retained infrastructure

- SwiftUI shell, conversation persistence, speech controls, and updater.
- Mentor trace serialization and explicit GitHub sync.
- Candidate branch, pull request, CI, release verification, and rollback
  conventions.
- Bounded development compiler and explicit user-approval boundary.
- Source-evidence records, URL/date visibility, and research quality gates.

## Retired capability families

The following families are removed only after the new core accepts their
regression replacement tests. They are not part of the product contract.

- Desktop application discovery, opening, UI interaction, and screen probes.
- Local workspace indexing, file queries, Finder reveal, file moves, and local
  document generation.
- Legacy intent, route, goal, and capability-learning chains that exist only
  to support the retired desktop/file product.
- Browser-control learning suggestions created from a research-quality
  shortfall.

## New core modules

### Conversation runtime

Maintains a compact conversation summary and routes only by the user goal:
conversation, public research, or repository development. A model gateway is
required for ChatGPT/Codex-quality generation; local fallback may provide only
a clearly-labelled limited response.

### Research runtime

Creates multiple independent source queries, reads bounded source pages in
parallel, records URL/date/excerpt evidence, evaluates source diversity and
authority, then either synthesizes a cited answer or states what is missing.
A failed quality gate is a research outcome, never a browser-control gap.

### Development runtime

Creates an isolated Git candidate from a user-approved development brief,
collects repository evidence, writes a plan and patch, runs deterministic
tests, and stops at review. GitHub integration is explicit and no release is
created without a separate approval.

## Acceptance gates

1. A public-research request cannot invoke desktop, file, or browser-control
   capabilities.
2. A research response either contains evidence records or refuses a factual
   conclusion; it never converts low source quality into a capability gap.
3. A development request produces a candidate plan before any code mutation.
4. No candidate can merge, tag, or release without user approval and passing
   CI.
5. Each user-facing quality claim has a deterministic regression test plus a
   live evaluation trace.

## Migration order

1. Introduce the new core contract and its regression tests.
2. Route the chat UI to the new conversation/research/development runtime.
3. Migrate Mentor and candidate-development reporting.
4. Delete retired desktop/file families and their obsolete UI/diagnostics.
5. Run GitHub CI and targeted live evaluations before each release.
