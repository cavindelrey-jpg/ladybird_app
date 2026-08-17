# Autopilot Mode — Standing Instructions

This file is auto-loaded by Claude Code every session started inside this
project. It is what makes "autopilot" actually work — read it before
starting any task from the numbered playbook files.

## Core rule: never idle waiting on me

- Do not stop a task to ask a clarifying question and then sit idle.
- If a decision is ambiguous, pick the most reasonable default given the
  context of this project, write down the assumption you made, and
  continue immediately.
- If you genuinely must ask something, ask it once, then **do not block**
  — proceed with your stated default right away rather than waiting for
  a reply. Treat silence as approval of the default you proposed.
- Log every assumption/default you make to `docs/AUTOPILOT_LOG.md` as you
  go (create it if it doesn't exist), one line per decision, so I can
  review the full list afterward instead of being interrupted for each
  one individually.

## The only things worth actually stopping for

Stop and wait for a real answer from me only if the action is one of:
- Deleting or force-pushing anything outside this local repo (a remote
  branch, a shared branch, a production Firebase project)
- Spending real money (a paid API call, a paid service signup)
- Permanently deleting production/live data (not local dev data, not
  test data)

Everything else — file structure, naming, which default color/copy to
use for a placeholder, which of two reasonable implementations to pick —
decide it yourself and move on. That's the point of autopilot mode.

## Session hygiene (this is what keeps autopilot safe)

- Commit after every completed step in the playbook files, with a clear
  message. Git history is the actual undo button here — that's what
  makes it safe to not stop and ask permission for every small decision.
- Run `flutter analyze` after any change touching more than ~10 files
  before continuing to the next step.
- Never work directly on `main`/`master` — confirm you're on the correct
  feature branch (per each playbook file's instructions) before making
  changes.

## Recommended way to launch a fully unattended run

For a step you want to run genuinely hands-off (e.g. overnight, or while
you're presenting somewhere else), start it as:

```
claude --permission-mode acceptEdits -p "<paste the day's prompt block>"
```

`acceptEdits` auto-approves file edits without a manual prompt each time,
which — combined with the rules above — is what removes essentially all
the stopping points. Reserve `--dangerously-skip-permissions` (full
bypass, including shell commands) only for a session you're actively
watching, since it also skips confirmation on destructive shell commands.

## Navigation — orient before searching

`lib/` layout, and the CORE/SCHOOL/SHARED classification of every feature
dir, is already written up in `docs/ARCHITECTURE_REPORT.md` — read that
before running broad greps across `lib/` to get oriented. `docs/AUTOPILOT_LOG.md`
tail has the current state of in-flight work.

Quick map (file counts as of 2026-08-17, will drift — treat as a starting
point, not ground truth):
- `lib/features/` — 58 files across 17 subfolders; biggest are
  `academic_content` (7), `testing` (6), `institution` (6)
- `lib/models/` (27) and `lib/repositories/` (25) — data layer, each has
  a barrel file (`models.dart`, `repositories.dart`) that re-exports the
  whole directory
- `lib/services/`, `lib/widgets/`, `lib/theme/`, `lib/screens/`,
  `lib/providers/`, `lib/core/`, `lib/config/`, `lib/pages/` — smaller
  SHARED infra; `lib/pages/` in particular is a flat grab-bag, not a
  feature dir (see ARCHITECTURE_REPORT.md for what's actually in it)

Scope `Grep`/`Glob` to the relevant subfolder instead of searching all of
`lib/` — there's no semantic-code-search MCP wired up here. Evaluated one
on 2026-08-17: every available semantic-code MCP server (claude-context,
claude-context-local, semantic-code-mcp) lacks Dart support entirely, so
one would index only the small JS/Node folders and silently miss this
app — not worth the added infra (Docker/API keys/local models) for that
coverage gap. Don't re-evaluate this unless one of those tools adds Dart
support.
