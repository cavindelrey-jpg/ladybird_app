# TASKS_LOOP6.md — Zero-intervention loop scope

Work through these in order. Never stop for input — see Rules at the bottom.

## 1. Magazine: descriptions + more categories
- Add a `description` field to MagazineArticle (short summary, separate
  from the full body) — shown on feed cards instead of/alongside the
  current auto-truncated body snippet. Add a description input to the
  composer.
- Expand categories beyond "Story" — add at least "Creative Writing" as
  its own distinct category, and review the existing category list for
  other genuinely missing common types (Essay/Opinion/News already
  exist per earlier session work — verify, don't duplicate).

## 2. Smoother video uploads on slow connections
Real, scoped fixes — not a promise of true resumable/chunked upload
(that's a bigger infra project, flag it in REPORT.md as a future item
if you conclude it's warranted, don't attempt it blind):
- Show a real upload progress percentage (Firebase Storage's
  `UploadTask.snapshotEvents` already exposes this — wire it into the
  UI wherever a video upload currently just shows an indeterminate
  spinner).
- Compress video before upload if a reasonable pure-Dart/Flutter option
  exists without adding heavy new native dependencies — check
  `pubspec.yaml` for anything already available before adding a new
  package.
- Add a retry-on-failure path instead of silently failing/hanging.

## 3. Rich editor should preserve structure on paste
Test pasting a complex formatted document (headings, numbered steps,
bold text, bullet lists) into the Magazine/Course Quill editor. Confirm
whether flutter_quill's paste handling preserves that structure or
flattens it to plain text. If it flattens: check flutter_quill's own
clipboard/paste configuration options (this version is 11.x) for a way
to preserve HTML/rich clipboard content rather than building a custom
parser from scratch. Note in REPORT.md exactly what does and doesn't
survive paste (e.g. headings: yes/no, bold: yes/no, numbered lists:
yes/no) so it's a known, tested boundary rather than a guess.

## 4. Home page visual redesign
Reference mockup: `home_page_reference_mockup.png` — put this file in
the project root before starting the loop so Claude Code can actually
view it, not just read the transcribed description below.

### 4a. Pure visual polish (safe to build directly, no new backend)
- Quick Access icons: give each a distinct tinted background + soft
  glow (Magazine=purple, Library=blue, Clubs=gold, Past Questions=
  green, Quizzes=orange) instead of uniform styling.
- Library banner: dark-to-transparent gradient overlay with "Library",
  a real resource count (query the actual count, do not hardcode),
  and an "Explore Now" button.
- Subtle section background tinting (very light blue-tinted gradient at
  top fading to white, alternating near-white section backgrounds)
  instead of flat white throughout.
- Micro-animations: cards lift slightly on tap, icons gently animate in
  on first load, notification bell wiggles when there's an unread
  count (real count, already wired earlier tonight), banner slow
  Ken-Burns zoom, XP bar animates when its value changes.
- Bottom nav: active tab sits inside a floating capsule/pill
  (Material 3 style) instead of a flat icon+label. Keep the existing
  5-tab structure and destinations exactly as they are — this is a
  restyle of the indicator, not a nav change.
- Very subtle (3-5% opacity) academic-symbol watermark decorations in
  section backgrounds (compass, atom, book, graduation cap) — decor
  only, must never interfere with text contrast/readability.

### 4b. Needs real new backend — build properly, do not fake
- **Streak tracking**: does NOT exist anywhere in the codebase today
  (verified: only a code comment mentions it as a future idea). Build
  a real daily-activity streak: a Firestore field/subcollection
  recording the user's active days, a computed consecutive-day streak
  count, and the Mon-Sun dot-row UI reading real data. Do not display
  a streak number without a real backing calculation.
- **"Continue Reading"**: does NOT exist anywhere today. Build real
  last-read-position tracking (which course/article, and page/scroll
  position) written whenever a user reads, and surfaced on Home as
  "Continue Reading: <title>, Page X of Y" using real data. If no
  course/article has been read yet, show a genuine empty/prompt state,
  not a fabricated example.
- **XP points / Courses count chips**: these ARE real and already
  computable (XP system and `user.courseIds.length` both already
  exist) — just surface them, no new backend needed.

### 4c. Explicitly OUT OF SCOPE this loop — do not build, do not fake
- **Daily Challenge / quiz card**: the mockup shows "Today's Physics
  Quiz, 3 Questions, +50 XP." No quiz feature exists anywhere in this
  codebase (confirmed multiple times). Building question/answer/
  grading logic is a real feature project, not a polish task, and is
  explicitly out of scope here. Do NOT build a fake/hardcoded quiz to
  fill this card. Either omit the card entirely for this pass, or (if
  you judge it worth the small effort) show it as an honest "Coming
  Soon" card using the existing ComingSoonPage pattern — never with
  fabricated question data.
- **Streak reward tiers (gold at 30 days, sparkle at 100, diamond at
  365)**: fine to build the visual states themselves, but do not
  fabricate a user's streak count to demo them — they should only ever
  render from the real streak count built in 4b.

## Rules — read before starting
- Never stop and wait for input. If something needs a live device, a
  design decision, or credentials — skip it, write one line to
  REPORT.md, and move on immediately.
- Use `--dangerously-skip-permissions` behavior is already set at the
  loop-script level — you do not need to request approval for
  Bash/Edit actions in this session.
- Resolve `flutter`'s full path before relying on it (see CLAUDE.md).
- Follow the existing repository pattern (Result<T>, Success/Failure)
  and existing UI conventions (C./Rad./AppText) exactly.
- No fabricated data, ever — this applies especially hard to section
  4b/4c above given the explicit history of fake badge counts and fake
  quiz data being called out as bugs earlier in this project.
- Run `flutter analyze` after each numbered section and fix what it
  flags before moving on.
- Commit after each section completes and analyzes clean.
- When fully done, write a final REPORT.md: what got built, what got
  skipped/deferred and why, and the final `flutter analyze` output
  verbatim.
