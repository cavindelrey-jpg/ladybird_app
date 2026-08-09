# Day 3 — Visual Polish + Demo Path

By now: no visible bugs (Day 1), two visibly distinct products (Day 2). Today is about making the specific path you'll walk through on stage feel finished, and having a plan for when something inevitably glitches live.

```
cd C:\Users\12406\academia_cameroon\academia_app
git checkout -b demo-prep-day3
git add -A && git commit -m "checkpoint before final polish"
```

---

## 1. Decide your demo path BEFORE touching more code
This is the one decision in the whole 3 days you should make yourself, not delegate to autopilot — it's a presentation-content choice, not an engineering one. Pick 5–8 screens per product that you will actually show.

Suggested Academia path: Homepage → Search → a Course → Library → a Club.
Suggested Green Hill path: Branded homepage/splash → Attendance or Timetable screen → back to a shared feature (Library/Courses) to show "same engine, school-branded."

Write this list down before the next prompt.

## 2. Loading/empty/error states on the demo path only
```
[AUTOPILOT: scope strictly to the screens listed below — if you notice
issues elsewhere, log them to docs/DEFERRED_ISSUES.md instead of fixing
them now, and keep going.]

For exactly these screens: [paste your demo path list here], ensure
each has a proper loading state (not a blank white screen), a proper
empty state if data can legitimately be empty, and no unhandled
exceptions that would show a red error screen.
```

## 3. Banner/image polish on the demo path
```
On the homepage and courses/library banners specifically, replace any
obviously placeholder or broken images with real assets I provide, and
ensure images have a loading placeholder so nothing flashes blank while
loading. Skip anything not on the demo path.
```
Drop real banner images into the relevant assets folder yourself before running this — same reasoning as the Day 2 branding assets, this is your content call, not Claude Code's.

## 4. Performance pass on the demo path
```
For the screens on my demo path, check for and fix: unnecessary full
widget-tree reloads on navigation, duplicate Firestore reads on the
same screen, and any obvious jank on scroll (unbounded ListView without
itemExtent/cacheExtent, images not sized/cached). Report what you
found and fixed per screen to docs/DAY3_CHANGES.md.
```

## 5. Record a fallback
Once the demo path is solid, screen-record a clean run-through of both apps on your actual demo device (not the emulator — emulator glitches don't happen live but device quirks do). This is your fallback if wifi/Firestore hiccups during the real presentation — you switch to the recording without missing a beat. Do this step yourself; it's not a Claude Code task.

## 6. Final verify (autopilot closing prompt)
```
[AUTOPILOT: run steps 2 and 4 above end-to-end without stopping between
them, committing after each. If anything you find doesn't clearly belong
in "fix now" vs "log and defer," default to logging and deferring —
today's goal is a stable demo path, not maximum polish.]

Build final release versions of both APP_MODE variants. Walk the exact
demo path on a real device for each. Report any remaining issue,
however small, to docs/DAY3_VERIFICATION.md.
```

```
git add -A && git commit -m "Day 3: demo path polished and verified"
```

Move to `04_PRESENTATION_CHECKLIST.md` once this is clean.
