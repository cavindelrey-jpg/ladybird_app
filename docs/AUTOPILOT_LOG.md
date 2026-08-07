# Autopilot Decision Log

One line (or short paragraph) per non-obvious default chosen without stopping to ask. Chronological.

## Session start (2026-08-07)

- **Branch naming**: chat instructions said a single branch `demo-prep` (not per-day
  `demo-prep-day1/2/3` as the pre-existing `01_DAY1...md`/`02_DAY2...md` planning docs
  describe). Chat instructions are the more specific/current source, so used one
  `demo-prep` branch for the whole session, working through items 1-6 as commits on it.
- **Pre-existing uncommitted WIP on `main`**: found uncommitted changes to `CLAUDE.md`,
  `lib/main.dart`, `lib/repositories/serial_repository.dart`, plus untracked
  `functions/serials.js` and `firestore.rules.snippet` — a coherent, already-finished
  prior change moving serial-code claim/generate/revoke/release off direct client
  Firestore writes and onto Cloud Functions (server-enforced), not part of this
  session's 6 numbered tasks. Rather than discard or leave it dangling uncommitted
  (risk of losing it, or it silently conflicting with this session's Firestore rules
  edits in task 2), committed it as its own baseline commit on `demo-prep` before
  starting task 1. Did not additionally wire `functions/serials.js` into
  `functions/index.js` or merge `firestore.rules.snippet` into `firestore.rules` as
  part of this commit — that wiring is outside this session's scope (serials/licensing
  flow, not the demo-readiness punch list) and functions/index.js wiring was not
  present in the working tree to begin with. Left `firestore.rules.snippet` in place
  as reference; will consult it if the `serials` collection rules become relevant to
  task 2's rules work.
- Numerous untracked planning/scratch files present at repo root (`00_INDEX_AND_GOAL.md`,
  `01_DAY1_CRITICAL_FIXES.md`, `02_DAY2_BRANDING_AND_SPLIT.md`, `03_DAY3_POLISH_AND_DEMO.md`,
  `04_PRESENTATION_CHECKLIST.md`, `COMPILER-PROCESS.md`, `Vibe Fix.md`,
  `course-computer-science.md`, `course-computer-science (1).md`, `course-mathematics.md`,
  `morphing.md`, `build_error.txt`, `build_log.txt`, `deps.txt`) — left untouched for now,
  not part of the numbered task list. Will not commit them as part of code-change commits;
  may fold into a single "misc scratch files" commit at the end if they're still untracked
  and clutter is worth resolving, otherwise leaving as local untracked scratch is harmless.
