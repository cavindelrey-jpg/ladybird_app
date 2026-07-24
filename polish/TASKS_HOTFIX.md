# Hotfix backlog — verify against real local files, don't assume

Same loop mechanism as polish/TASKS.md — one item per commit, gated by
`flutter analyze`. Run with:
  .\polish-loop.ps1 -TasksFile polish/TASKS_HOTFIX.md

IMPORTANT: for every item below, read the actual current file first and
confirm the described symptom is really there before fixing anything.
The exact line numbers, variable names, and surrounding code may differ
from what's described here — the local files are the source of truth,
not this description. If an item turns out to already be fixed or the
code looks structurally different from the description, mark it done
with a one-line note explaining what you actually found, rather than
forcing a change to match the description.

## 1. Drawer's "Home" item doesn't return to the Home tab
Symptom: opening the hamburger drawer from any tab other than Home
(e.g. Courses, Profile) and tapping "Home" in the drawer just closes
the drawer — it leaves you on whatever tab you were already on, instead
of switching to Home.
Look in `lib/widgets/app_drawer.dart` for the drawer's Home list item —
check whether its `onTap` only calls `Navigator.of(context).pop()` (closes
drawer only) versus also resetting whichever tab-index state variable
the shell (`lib/screens/app_router.dart`, likely `HomeShell` and/or
`GuestShell`) uses to pick which page the bottom nav shows. If it's
pop-only, wire a callback from the shell into `AppDrawer` (e.g. an
`onGoHome` VoidCallback param) that both closes the drawer and resets
the tab index to 0. Check every place `AppDrawer(...)` is constructed
(there may be more than one shell) and wire all of them the same way.

## 2. Hero Slide "Custom" destination does nothing when tapped
Symptom: a Hero Slide banner configured with destination "Custom" (set
via the Hero Slide Manager, which has a "Custom Route" text field) does
nothing at all when tapped.
Look in `lib/features/dashboard/universal_home_page.dart` for the
switch/if-else that handles `HeroDestination` values (likely in a
method named something like `_openHeroSlide`). Check whether the
`custom` case is an empty no-op. There is no named-route system
anywhere in this app (confirmed) to map an arbitrary string to an
in-app screen, and the admin field doesn't specify what it's meant to
contain. Fix: if the custom route value looks like a URL
(`http://`/`https://`), launch it externally (`url_launcher` package,
already a dependency — check `pubspec.yaml`). Otherwise, show a real
message telling the admin the destination isn't configured/supported,
instead of silently doing nothing. Do not invent a fake in-app route
table to make this "fully work" — that would be fabricating behavior
that doesn't have real backing anywhere else in the app.

## 3. Verify (don't assume) — these may already be fixed
For each of these, check the actual current file. If the symptom
described is NOT present, mark it done with a note saying what you
actually found instead of changing anything.
- [ ] **Home tab shows wrong user/guest state**: check
      `lib/screens/app_router.dart`'s tab-building logic — does the
      'Home' case construct `UniversalHomePage` with the real logged-in
      user passed in, or with no user argument (defaulting to null/guest)?
- [ ] **Banner doesn't auto-advance**: check
      `lib/features/dashboard/universal_home_page.dart` for the banner
      carousel's PageController — is there a `Timer.periodic` (or
      equivalent) auto-advancing it, or is it manual-swipe-only?
- [ ] **Home page avatar not tappable**: check the greeting-row avatar
      widget on Home — does tapping it navigate to the Profile page, or
      is it a bare CircleAvatar/Container with no gesture handler?

## Rules
- Read the real file before changing anything — this list describes
  symptoms and likely locations, not verified line-accurate diffs.
- Never stop and wait for input. If something needs a live device, a
  design decision, or credentials — skip it, log one line to
  `polish/logs/` or REPORT.md, and move on.
- Run `flutter analyze` after each item and fix anything it flags
  before moving to the next.
- One commit per item, with a clear message.
- No fabricated behavior — if a fix requires guessing at something with
  no real backing (like item 2's custom route), be honest in the code
  comment and user-facing message about the limitation rather than
  inventing a fake full solution.
