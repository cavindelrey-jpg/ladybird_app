# Day 1 — Critical Fixes (highest priority — do these first)

Confirm `CLAUDE.md` is already copied into `academia_app\` before starting (see `00_INDEX_AND_GOAL.md`). Without it, Claude Code will still pause on ambiguous decisions — the autopilot behavior only kicks in once that file is in place.

```
cd C:\Users\12406\academia_cameroon\academia_app
git checkout -b demo-prep-day1
git add -A && git commit -m "checkpoint before demo-prep polish"
```

Launch Claude Code for this session (pick one):
```
claude                                                  # interactive, you watch each step
claude --permission-mode acceptEdits -p "..."            # autopilot, hands-off
```

Work through 1–5 in order. If running interactively, commit after each numbered section yourself. If running autopilot end-to-end, the closing prompt in section 5 tells it to commit after each section on its own.

---

## 1. App logo / branding not updating
```
[AUTOPILOT: if the correct source logo file's location is ambiguous,
search assets/ yourself, pick the most recently added image file that
looks like a logo, log the assumption to docs/AUTOPILOT_LOG.md, and
proceed — do not stop to ask.]

The app icon and splash screen still show the old logo despite a new
logo being added under assets/icon. Investigate:
1. Whether the icon-generation config (flutter_launcher_icons or
   equivalent) points at the correct source file
2. Whether the icon generation command has actually been re-run since
   the asset changed
3. Whether any hard-coded old logo reference exists elsewhere (splash
   screen widget, app bar, about page)
Fix the config, regenerate icons/splash, and grep the codebase for any
remaining reference to the old asset path. Report every file changed.
```

## 2. Firestore permission / index errors
```
[AUTOPILOT: do not stop to ask before writing firestore.indexes.json or
firestore.rules changes — these are local file edits, not production
deploys, so they're safe to make and log. Only the actual `firebase
deploy` command later is a real checkpoint, and that's run by me
manually, not by you.]

Multiple screens throw "permission denied" or "the query requires an
index" from Firestore: Recommended for You, Top Writers, Library,
Search, and Past Questions.

1. Find every Firestore query in lib/ related to these features.
2. For each, list the collection, filters/orderBy used, and whether it
   needs a composite index.
3. Generate/update firestore.indexes.json with every required index.
4. Review firestore.rules against each query's read path — identify any
   rule mismatch and fix it. Do not weaken rules to "allow read: if
   true" as a shortcut — scope correctly to the real access pattern.
Output a summary table: Feature | Query | Index Added | Rule Fixed.
```
Then deploy for real yourself (this is the one step you do manually, not Claude Code — it changes live Firestore config):
```
firebase deploy --only firestore:indexes,firestore:rules
```

## 3. Dead buttons and broken navigation
```
[AUTOPILOT: if the "correct" destination for a button isn't obvious
from existing routes, pick the most sensible existing route/page,
implement it, and note the assumption — don't stop and ask which page
it should go to.]

Audit and fix these specific dead/broken interactions:
- Daily Challenge button (homepage) — currently does nothing
- Today's Progress button (homepage) — currently does nothing
- Profile icon/name tap — should open Profile page, currently doesn't
- Discover Clubs "See All" — currently does nothing; should navigate to
  the full clubs list, or show an empty state if there are no clubs
- Clubs search bar — disappears when the user types (a state-management
  bug, likely a rebuild collapsing focus); fix it so it stays visible

For each, trace the onTap/onPressed handler to find why it's a no-op,
then wire it to the correct route or fix the underlying state bug.
Report before/after behavior for each item.
```

## 4. Homepage search returns nothing
```
Homepage search returns zero results even with content in Firestore and
an active connection. Investigate whether the query hits the right
collection, whether it's doing a naive equality match against free
text instead of a real search pattern, and check Firestore rules for
the search path. Fix it so it returns real results. Explain the root
cause you found.
```

## 5. Verify before moving to Day 2 (full autopilot closing prompt)
```
[AUTOPILOT: run this end-to-end without stopping between steps. Commit
after each of the four fixes above individually before starting the
next one, using a clear commit message per fix. Then do the following.]

Run flutter analyze and flutter test. Then smoke-test manually:
homepage loads with no console/Firestore errors, Daily Challenge and
Today's Progress navigate somewhere real, profile tap opens Profile,
search returns results, Discover Clubs See All works. Report pass/fail
per item to docs/DAY1_VERIFICATION.md, and append every assumption you
made along the way to docs/AUTOPILOT_LOG.md if not already there.
```

```
git add -A && git commit -m "Day 1: critical bug fixes verified"
```

**Do not proceed to Day 2 until `docs/DAY1_VERIFICATION.md` is clean.** Read it yourself, even if the run was autopilot — autopilot means Claude Code didn't stop to ask you things, not that you skip reviewing what it decided.
