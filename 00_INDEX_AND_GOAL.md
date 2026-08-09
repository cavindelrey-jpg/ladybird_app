# Academia + Green Hill — 3-Day Demo-Prep Index (Claude Code edition)

## Project location
`C:\Users\12406\academia_cameroon\` contains three subfolders:
- `academia_app` — this is where Day 1–3 work below happens (the Flutter app)
- `academia_compiler` — out of scope unless a step explicitly says otherwise
- `academia_loop` — out of scope unless a step explicitly says otherwise

Every command below assumes you've `cd`'d into `academia_app` first:
```
cd C:\Users\12406\academia_cameroon\academia_app
```

## Autopilot setup — do this before anything else
Copy `CLAUDE.md` (in this same folder) into `academia_app\CLAUDE.md`. Claude Code reads it automatically at the start of every session in that directory — this is what makes it not stop and wait on you mid-task. **Do this once now, before Day 1.**

## The actual goal
Not "feature-complete." **Demo-ready.** In 3 days:
1. Every screen a viewer will tap during the presentation works, no visible Firestore errors, no dead buttons.
2. Academia (platform) and Green Hill (first client) visibly look like two different products, built off the same codebase.
3. A rehearsed presentation flow where you control what gets shown.

## How to use this folder
Numbered = priority order. Work top to bottom. Each file is one Claude Code session. Commit after each one, verify it worked, then move to the next file.

| File | Day | Covers |
|---|---|---|
| `CLAUDE.md` | Setup | The autopilot standing instructions — copy into `academia_app` first |
| `01_DAY1_CRITICAL_FIXES.md` | Day 1 | Kill every visible bug: logo, Firestore errors, dead buttons, search, nav |
| `02_DAY2_BRANDING_AND_SPLIT.md` | Day 2 | Make Green Hill visibly a distinct product off the same codebase |
| `03_DAY3_POLISH_AND_DEMO.md` | Day 3 | Visual polish pass + rehearsed demo path + fallback plan |
| `04_PRESENTATION_CHECKLIST.md` | Day 3 (end) | Final go/no-go checklist |

## What's explicitly OUT of scope for these 3 days
Full messaging rebuild, quiz/course auto-generation pipeline, club roles/moderation, admin banner CMS, dark mode audit, the desktop web app, the marketing site. If a Claude Code response starts wandering into these, stop it and redirect back to the current file's scope — autopilot mode makes it move fast, which also means it can drift fast if a prompt is under-scoped.

## How to actually run each step
Two ways, both fine:
- **Interactive, watching:** run `claude` in the terminal, paste the prompt block, let it work, review the diff before the next prompt.
- **Unattended, autopilot:** `claude --permission-mode acceptEdits -p "<prompt block>"` and walk away. Combined with `CLAUDE.md`, this is the actual "carries on automatically, doesn't wait on you" setup — use this when you genuinely can't babysit a step (e.g. overnight, or you're in a meeting).

One prompt file section = one Claude Code invocation = one commit. Don't chain multiple sections into a single prompt.
