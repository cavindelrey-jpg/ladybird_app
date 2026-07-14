# TASKS.md — Current Bug/Feature Backlog

Work top to bottom. Fix ONE item at a time, then stop and report what changed so it can be tested on device before moving to the next. Do not batch multiple P0 items into one commit — they touch different subsystems and need individual verification.

## P0 — Blocking bugs (fix first, in this order)

1. **Async operations never resolve their loading state on success.**
   Reported symptom: on login, entering email/password and pressing "Sign In" spins forever — but the login actually succeeded (pressing Back and returning to Home shows the user logged in). This means the Future/async call completes and updates auth state, but the button's loading state and navigation are not tied to that completion — likely a missing `Navigator` call after `await` resolves, or a loading flag not reset, or the widget listening to the wrong stream/notifier.
   Check: does this same pattern (stuck spinner, button non-responsive) appear on any other async action — course creation, uploads, etc? Fix the pattern once, not just the login instance, if it's a shared button/loading component.

2. **Home button (bottom nav) leads to a black page.**
   Diagnose whether this is a null/uninitialized provider, a missing Scaffold body, or an unhandled exception being swallowed silently.

3. **Courses tab leads to an incomplete/unfinished page.**
   Identify what's actually missing vs. stubbed.

4. **Adding a course freezes the app.**
   Likely a blocking synchronous call on the main isolate, an infinite loop, or an unhandled exception during a Firestore write. Needs a real fix, not a timeout workaround.

## P1 — Missing core functionality (real features, not stubs)

5. **File rendering, not just upload.** Uploaded PDFs, videos, and images must render in-app when opened — not just show as an uploaded thumbnail/placeholder.
6. **Library needs an in-app PDF reader and media player** (video/audio), not just a bookmark list.
7. **Courses and Magazine composer should support rich in-line content** — images embedded inline within formatted text (like a word processor), not just a thumbnail attached to a post. This affects the existing `flutter_quill`-based editor — confirm inline image embedding is actually wired up, not just accepting a cover image.

## P2 — UX polish

8. Home page "Recommendations" cards should show an icon per item, not just text.
9. "Switch account" button is present but empty/non-functional.
10. Any place a profile picture is shown (avatar) should be tappable and navigate to that user's Profile.
11. Replace the default Flutter launcher icon with the actual Academia logo (navy/gold "A" mark) — check `android/app/src/main/res/mipmap-*` and `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
12. General load-time complaints (uploads, page loads feel slow) — profile this only after P0/P1 are done; premature optimization here will just get overwritten by the async-state fix in item 1.

## Notes
- Item 1 (stuck spinner / login) is almost certainly the highest-impact fix — it makes the app look broken even when it isn't. Start there.
- After each fix, report back exactly what file(s) changed and what to test manually — these are runtime/UX bugs, `flutter analyze` and a clean build will NOT catch whether they're actually fixed.
