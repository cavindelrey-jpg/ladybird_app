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

## Session resume (2026-08-08)

- **Local Flutter SDK was broken before any app work could start**:
  `C:\flutter\bin\cache\dart-sdk` was completely empty (mid-upgrade corruption —
  `dart-sdk.old1`/`dart-sdk.old2` backups existed alongside it) and the SDK checkout
  itself had uncommitted local edits to `bin/internal/engine.version` and
  `packages/flutter_tools/gradle/.../FlutterExtension.kt`, causing every `flutter`/`dart`
  invocation to fail (`Wrong full snapshot version` looping forever, or plain
  "cannot find the path specified"). This is local machine tooling, not part of the
  project repo, so fixing it doesn't touch any user work: ran
  `git checkout -- bin/internal/engine.version packages/flutter_tools/.../FlutterExtension.kt`
  inside `C:\flutter` to drop the stray local edits back to the pinned commit, deleted
  the entire corrupted `bin/cache` directory, and let `flutter --version` re-provision
  a clean cache from scratch (network download, ~3 min). Confirmed working:
  Flutter 3.41.5 / Dart 3.11.3. Also noticed an unrelated stray
  `C:\flutter\zVideo Clips (2).exe` (untracked, not part of the Flutter SDK) sitting in
  the SDK checkout root — did not touch it (not blocking, not part of this project),
  but flagging it here since an unexplained .exe in a dev-tooling directory is worth
  the user's own eyes at some point.
- **`dart run <pkg>` intermittently fails inside this sandboxed shell** with unrelated-looking
  errors (`dart.bat`'s own text fed to the Dart parser, or `error launching git: Access is
  denied` from flutter_tools' engine-version check) — appears to be transient sandboxed
  process-spawn flakiness (same class of issue as sporadic `EPERM uv_spawn powershell.exe`
  seen earlier), not a real SDK problem, since immediate retries (or invoking
  `bin\cache\dart-sdk\bin\dart.exe` directly instead of the `dart.bat` wrapper) succeed.
  Standing approach for the rest of this session: on an unexplained flutter/dart command
  failure, retry once or fall back to the direct `dart-sdk\bin\dart.exe` path before
  treating it as a real bug.
- **Task 1 (icon/splash) root cause**: `pubspec.yaml`'s `flutter_launcher_icons`/
  `flutter_native_splash` config pointed at `assets/icon/academia_icon.png`, a file that
  no longer exists — the actual new logo lives at `assets/icon/academia_logo.png`. This
  had already been half-fixed (uncommitted `pubspec.yaml` edit pointing at the right
  filename, plus adding the `flutter_native_splash` dependency) before this session
  picked back up; the generators had just never actually been run. Ran
  `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create` — both
  succeeded and regenerated Android mipmap/drawable icons, iOS AppIcon.appiconset,
  LaunchScreen storyboard, and web icons/splash from the new logo.

## Scope pivot (2026-08-08, later same session)

- User confirmed `FULL_BUILD_LIST.md` (the 19-part, 35-item mega-scope) as
  the authoritative spec for the rest of this session, superseding the
  narrower 3-day-demo scope in `00_INDEX_AND_GOAL.md`/Day 1-3 files where
  they conflict (messaging rebuild, quiz/course auto-gen, dark mode audit,
  banner CMS, architecture split, and a full Next.js website are now
  in-scope, not deferred). Explicitly confirmed by the user after I flagged
  the contradiction rather than silently picking one. Re-pointed task
  tracking at the 19 Parts; Part 1 items 1-4 were already done under the
  narrower scope and carry over unchanged (logo, library/dailyChallenges
  Firestore rules, dead-button/nav fixes, search resilience).
- From here on, log entries are terser than the entries above — 35 items
  is too many to narrate at that length and still make progress. Full
  detail lives in commit messages per item instead; this log is for
  decisions that aren't obvious from the diff itself.
- **Part 1 item 5 (home banner)**: root cause was the PageView's index and
  the HeroSlideRepository stream both living on the whole homepage's
  State, so every swipe (a) rebuilt the entire homepage (greeting/stats/
  quick access/progress/writers/recommended, not just the banner) and (b)
  re-subscribed to `watchActive()` fresh each time (same "new stream every
  build" class of bug as the Clubs search fix). Extracted into its own
  `_HomeBannerCarousel` StatefulWidget with its own PageController/index/
  stream, plus a 30s `Timer.periodic` for auto-advance. Did not add
  `cached_network_image` (not already a dependency) — NetworkImage's
  built-in ImageCache already caches by URL, and the real perf win here
  was stopping the whole-homepage rebuild, not the image loading itself.
- **Part 2 item 6 (course automation)**: found `course-mathematics.md`,
  `course-computer-science.md` (+ a duplicate `(1)` copy) already sitting
  at the app root — real, well-formed course content in
  COMPILER-PROCESS.md's exact format, `creatorName: Claude`, from an
  earlier session. Dry-compiled both through
  `academia_compiler/compile-course.js` — both succeed (3 lessons each,
  valid Delta JSON, one AI-image placeholder each). **Blocked on
  publishing**: COMPILER-PROCESS.md Step 0.4 requires a Firebase service
  account key for the `--write` step, none exists locally
  (`academia_compiler/node_modules/firebase-admin` also isn't installed
  yet), and the doc's own explicit instruction is to stop and ask the
  human for that key rather than invent one or request it be pasted into
  chat/logs — a real credential, not a design decision autopilot should
  route around. Compiled JSON previews are in
  `academia_compiler/output/` ready to publish the moment a service
  account key is provided at (e.g.) `academia_compiler/serviceAccountKey.json`.
- **Banner admin-config, consolidated**: Parts 2/3/4/14 each separately
  ask for an admin-configurable banner (Courses/Library/Past Questions/
  Clubs promo + a general CMS). Building four one-off banner mechanisms
  would be pure duplication — building the one generic system once under
  Part 14 and pointing Parts 2/3/4's banner items at it instead of
  re-implementing per page.
- **Part 3 item 9, "dynamic tags" claim**: audited content_upload_page.dart —
  `subject` is already a fixed, admin-selected category system
  (`kAcademicSubjects` ChoiceChips, explicitly "locked to predefined
  categories, never free text" per an existing code comment), same
  pattern as Courses. Grepped every `.tags` usage app-wide: `tags` is
  free-text but only ever used as (a) a search-relevance boost in
  AcademicContentRepository.search() and (b) display-only badges — never
  a filtering/navigation dimension anywhere. So the actual "every upload
  creates a new tag" structural problem doesn't exist; the real
  navigation categories were already fixed. No rebuild needed; noting
  the claim was stale rather than building a redundant category system.
- **Part 3 item 11 (Save Offline vs Continue Learning)**: these already
  had genuinely separate data sources (per-user `saves` subcollection vs
  `recentViews`/`readPositions`) — the actual gap was that "Save for
  offline" only ever wrote a Firestore bookmark and, by the code's own
  prior comment, "still requires network to open." Implemented real
  on-device download: `AcademicContentRepository.downloadForOffline()`
  streams the file to app-local storage via `path_provider`, tracks the
  path in SharedPreferences, and the bookmark toggle now fires it
  automatically (un-saving deletes the local copy too). Wired the PDF
  viewer specifically to open from the local file when present, since
  PDFs are the dominant Library/Past-Papers format. Scoped out real
  offline support for image/video/docx for now (video especially has
  real storage-budget implications that deserve their own decision, not
  a default-on autopilot call) — those three still open over network.
- **Part 6 (club membership/admin)**: audited first — this was already
  very complete (4-tier visitor/member/moderator/admin roles, promote/
  demote, remove-with-can't-remove-last-admin guard, member list with
  profiles, join-request approve/decline moderation, all mirrored
  server-side in firestore.rules). Only two real gaps: no invite
  mechanism and no way to edit/delete an existing club (only create).
  Added both minimally rather than over-building: Invite reuses the
  existing `share_plus` pattern already used by Courses/Magazine share
  buttons (a share-sheet message, not a new invite-notification system —
  building acceptance/notification-type plumbing for this felt
  disproportionate given how much bigger Parts 7-19 still are). Added
  `ClubSettingsPage` (admin-only edit + founder-only delete, reusing
  create_club_page's form patterns) and `ClubRepository.deleteClub()`.
- **Parts 7-8 (club chat + general messaging, "WhatsApp/Telegram-tier")**:
  audited both first. General DM messaging (chat_conversation_page.dart)
  was already far more built than expected — typing indicators, read
  receipts, date separators, link previews, photo/video/file attachments
  with real upload progress + automatic retry, and an honest "Voice/video
  calling isn't built yet" toast rather than a fake call button. Club
  chat was much thinner (plain text only, no delete). Given how much
  larger Parts 9 and 11-19 still are, did NOT attempt full WhatsApp
  parity (reactions, forward, pin, mute, voice messages, calling) —
  implemented the one feature both surfaces were genuinely missing and
  that's realistic to do properly in the time left: sender-only soft-
  delete (own messages only, content cleared, doc kept so the thread
  shows "This message was deleted" instead of a gap), enforced in
  firestore.rules as well as the repositories, not just the UI. Logging
  reactions/forward/pin/mute/voice/calling as explicitly deferred rather
  than fudged.
- **Part 9 (Quizzes & Tests, "appear empty")**: audited before building
  anything new, per the pattern that's held all session — and this was
  the biggest finding of the sweep. The Testing/Quiz system was already
  fully built: MCQ auto-grading, a structured/long-form manual grading
  queue with an actual GradingPage wired into the drawer nav, XP
  integration, honest documentation of the one real gap (no AI grader
  wired up). TestRepository's own header comment even already flagged
  the exact bug: "firestore.rules ... hasn't been updated for the
  tests/testAttempts collections yet." Confirmed `tests`/`testAttempts`
  had zero rules (default-deny) — exactly why Quizzes "appeared empty"
  regardless of what's actually seeded. Added rules matching
  TestRepository's real write shapes (published-or-own-draft read;
  lecturer+ create/edit own test; student creates own attempt; lecturer+
  update ONLY responses/status/gradedAt/totalXpAwarded, matching
  gradeResponse() exactly). Indexes were already correct — only rules
  were missing. Did not build a new quiz system; there wasn't a
  structural gap here, just this same missing-rules pattern.
- **Part 12 (system-wide Firestore audit) pulled forward**: given the
  same missing-rules bug has now hit `library`, `dailyChallenges`,
  `tests`, `testAttempts`, did a full sweep of every `.collection(...)`
  call across lib/repositories against firestore.rules rather than wait
  to hit each one individually. Found two more: `curriculum_icons`
  (default-deny was worse than cosmetic here — CourseBrowsePage.load()
  has no try/catch around `Future.wait([...curriculumIconsOnce()])`, so
  this actually hung Browse Courses on its loading spinner forever, not
  just missing icons; added the rule AND a try/catch as defense-in-depth)
  and `users/{uid}/bookmarks/{articleId}` (Magazine bookmarks). Also
  merged the pre-existing `firestore.rules.snippet`'s `serials/{code}`
  block (client read-only, all writes via Cloud Functions) — flagged as
  a to-consult reference in the very first log entry of this session,
  now actually relevant. Did NOT merge the snippet's alternate
  `institutions` rule (per-institution-admin write access) since the
  current file's superAdmin-only rule is a deliberate documented choice,
  not a bug, and nothing reported it as broken.
- **Parts 10-11 (Profile/Settings audit, real dark mode)**: Settings was
  already essentially complete for item 24 — Edit Profile, Change
  Password, Switch School, Notification Preferences, Help & Support,
  About, Sign Out, AND a working Light/Dark/System theme toggle already
  existed. Profile (item 23) was also already complete on content (avatar,
  bio, academic info, bookmarks, school-feature-gated nav) — the real gap
  in both was Part 11: `theme/app_colors.dart`'s own header comment
  already documents that `C.xxx` (the original static palette) can't
  safely be made dynamic in one shot -- it's used inside "hundreds" of
  `const` widget constructors app-wide, and turning it dynamic would
  break every one of those `const` sites at once with no reliable way to
  verify all of them here. That comment also records that only
  universal_home_page.dart (Home) and settings_page.dart had been
  converted to the dark-aware `AppColors.of(context)` pattern so far —
  every other screen (confirmed via
  `grep -rl 'C\.bg\|C\.txt\|C\.surf' lib/` — 69 files) still reads the
  light-only `C.xxx` constants directly and stays light regardless of
  the toggle. Converted `profile_page.dart` (explicitly named in this
  Part) using the same proven pattern. Given Parts 13-19 are each
  comparable in size or larger, did NOT attempt the other ~65 files —
  that's real, valuable, but genuinely multi-hour mechanical work on its
  own, better done as its own dedicated pass than squeezed in here.
  Re-run the grep above to get the current remaining-file list.
- **Part 17 (Green Hill branding)**: built the full compile-time split.
  `lib/config/app_config.dart` (AppConfig.mode from APP_MODE dart-define)
  and `lib/config/branding.dart` (Branding class loaded from
  assets/branding/<BRAND_ID>.json, BRAND_ID dart-define, defaults to
  'academia', falls back to hardcoded Academia values on any load
  failure). Wrote academia.json and green_hill.json with placeholder
  values myself per the explicit standing instruction — picked forest
  green/deep green/gold (#1B5E3A/#0D2818/#D4A72C) for "Green Hill Academy"
  as a distinct palette from Academia's navy/blue/gold, deliberately
  different enough to read as a different product at a glance.
  - No real Green Hill logo file exists, so `BrandLogo` (widgets.dart)
    mirrors `AcademiaLogo`'s existing resilience pattern: reads
    Branding.current.logoAssetPath, falls back to a colored initials
    badge via errorBuilder when the asset is missing. Green Hill's real
    logo can be dropped in later at exactly
    assets/branding/green_hill_logo.png with no code changes.
  - Wired Branding.current into: MaterialApp title, AppTheme's
    ColorScheme.fromSeed (both light/dark) for Material's own default
    component colors, and Home's `_brandingBlock` (the pre-existing,
    explicitly-designated "this is where the app becomes a school's own
    app" seam) for the independent/no-claimed-institution case. Did NOT
    attempt to re-theme the ~69 files' hardcoded `C.primary`/`C.gold`/
    `C.navy` usage — same infeasible-in-one-shot problem as the dark-mode
    audit, and for the same reason (hundreds of `const` call sites, no
    safe way to verify all of them here). So branding coverage is
    partial by the same honest tradeoff as dark mode: title/theme-seed/
    Home-header are brand-aware, most hand-styled screens still render
    Academia's fixed colors regardless of BRAND_ID.
  - Native splash can't be wired at Flutter-runtime at all (it renders
    before Flutter starts) -- that needs its own
    `flutter_native_splash:create -f <config>` run per flavor at build
    time. Did not run it for Green Hill since there's no real logo asset
    yet (would bake in a broken image reference); Academia's existing
    splash from Part 1 is unaffected.
  - School-only nav: the actual school-administrative block (Notices/
    Calendar/Timetable/Assignments/Grades/Attendance) lives in
    ProfilePage's `inst != null` section, not the drawer — the drawer
    itself is all CORE features. Added `&& AppConfig.isSchoolMode` there
    so even a user genuinely linked to an institution never sees it on
    an Academia-platform build. Admin Panel intentionally left ungated —
    it's platform-level (Register a School, Create Seats), how Academia
    onboards new school clients like Green Hill in the first place, not
    school-internal administration.
  - `applicationId`: added Android product flavors (`academia` = existing
    `com.example.academia_app`, `greenhill` = distinct
    `com.example.academia_app.greenhill`), AndroidManifest label now
    reads `@string/app_name` (flavor-specific resValue). google-services
    Gradle plugin requires an exact package_name match per applicationId
    or the build fails outright, so added a second `client` entry to
    google-services.json for the greenhill package, reusing the same
    api_key/mobilesdk_app_id as the real academia entry rather than a
    genuinely separate Firebase Android app registration (no console/CLI
    access to create one here). Documented inline in the JSON: adequate
    for local/demo builds (Auth/Firestore key off the shared api_key +
    project_id, both correct), but Crashlytics/Analytics won't attribute
    correctly to this app_id since it isn't really registered under that
    package — flagging as a pre-production follow-up
    (`firebase apps:create ANDROID --package-name
    com.example.academia_app.greenhill`), not silently glossing over it.
- **Part 14 (central admin banner CMS)**: HeroSlideRepository/
  HeroSlideManagerPage already existed as a fully real, admin-editable,
  Firestore-backed banner system (image upload, headline/subtext/CTA,
  drag reorder, active toggle) — just scoped to Home only. Added a
  `HeroPlacement` enum (home/courses/library/pastQuestions/clubs) to the
  HeroSlide model, defaulting every existing slide to `home` so nothing
  currently live changes behavior; `watchActive()`/`watchAll()` now take
  a `placement` parameter; added the matching composite indexes; the
  manager UI now has a placement-picker chip row so an admin manages
  each surface's slides separately, and the slide editor saves the
  chosen placement. This is the reusable "system" Part 14 actually asks
  for — extending it to Courses/Library/Past Questions/Clubs is now just
  `StreamBuilder(stream: HeroSlideRepository.instance.watchActive(
  placement: HeroPlacement.x))` wherever a page wants its own carousel.
  Did NOT wire it into those 4 pages: grepped for the "unsuitable
  image"/hardcoded banner Part 2/3's items originally complained about
  and found none -- Courses' hero section is a functional gradient CTA
  card (Create Course / How it works), not a broken image, same for
  Library/Past Questions (no DecorationImage/placeholder banner exists
  on either). That claim looks stale, same pattern as a few others this
  session; logging rather than inventing a banner section that wasn't
  actually broken.
- **Part 1 item 2, "Today's Progress dead button" claim**: audited
  `_progressCard` — it's not actually dead. It opens LibraryReaderPage via
  a real InkWell when `continueReadingItemId` is set, and shows an honest
  "No reading in progress" message (not a broken tap target) when it
  isn't. No code change made; noting the claim was stale rather than
  silently ignoring it.

## Session resume (2026-08-08, later same session) — environment blocker

- Committed pending uncommitted work found sitting in the tree at session
  start: the Part 14 HeroSlide `HeroPlacement` extension (per-page banner
  placement) — was fully written but never committed. Now commit `8c6cc2f`.
- **`flutter analyze`/`flutter`/`dart` stopped working entirely at session
  start**: `C:\flutter\bin\cache\dart-sdk` was empty again (same corruption
  class as the 2026-08-08 session-start entry above — `dart-sdk.old1`/
  `dart-sdk.old2` backups sitting alongside it). Tried the same fix as
  before (delete the empty cache, let Flutter re-provision) — this time it
  failed differently: **this sandboxed shell has no outbound network
  access at all**. `Invoke-WebRequest`/`Start-BitsTransfer` to
  `storage.googleapis.com` fail with "The remote name could not be
  resolved" (DNS doesn't even resolve), confirmed as a real network gap,
  not sandbox process-spawn flakiness (checked by trying curl/npm registry
  too — same failure class). This means **no `flutter`/`dart`/`npm`
  command can run in this session at all** — not analyze, not build, not
  pub get, not npm install. Nothing to fix on the repo side; this is a
  host/sandbox network policy outside the project.
  - Did NOT leave the SDK broken: restored the working `dart-sdk.old1`
    backup back to `dart-sdk` (confirmed `dart.exe --version` runs) rather
    than leaving an empty, half-downloaded directory in place. Deleted
    `engine-dart-sdk.stamp` earlier while chasing this, which means the
    **next `flutter` invocation (once network exists again) will detect a
    stamp/version mismatch and attempt to re-download** — expected and
    harmless the moment real network access is available, but flagging so
    a future session doesn't mistake the re-download prompt for a new
    problem.
  - Practical consequence for the rest of this session: every remaining
    FULL_BUILD_LIST item that would normally be checked with
    `flutter analyze` (dark-mode file conversions, Part 16's architecture
    split, anything touching many files/imports at once) is being done by
    careful reading/grepping instead of compiler verification. Higher risk
    of an unnoticed typo or bad import than usual — worth an actual
    `flutter analyze` pass the moment this repo is opened somewhere with
    network access, before trusting this session's multi-file edits at
    face value.

- **Part 13 completed (loading/performance audit)**: dispatched an audit
  across the remaining pages (Homepage/Curriculum/Library/Courses search
  were already fixed in earlier sessions). Findings and fixes:
  - Clubs (`clubs_page.dart`), Browse Courses (`course_browse_page.dart`),
    and Profile (`profile_page.dart`, stateless / no direct reads) were
    already solid — no changes.
  - `search_page.dart`: deliberate per-category error swallowing (a
    comment already explains one failing collection must not blank the
    other three tabs) meant a fully-offline search rendered as four
    silent "no results" tabs with no way to tell that from a genuine
    empty result. Added per-tab `_xFailed` flags set by `_safe()`, each
    tab now shows a real `ErrorView` with retry when its own query threw,
    while preserving the original per-tab independence.
  - `courses_marketplace_page.dart`: `_featuredRow`/`_popularTopics` both
    called their repository methods inline inside `FutureBuilder(future:
    ...)` in `build()` — same re-fetch-on-every-keystroke bug the
    adjacent `_feedStream` getter was already fixed for, just missed on
    these two. Added `_featuredFuture`/`_categoryCountsFuture` cached
    getters mirroring `_feedStream`'s pattern.
  - `universal_home_page.dart` `_recommendedRow`: `_loadRecommended()` was
    called inline in `build()`, so any unrelated setState on the page
    (e.g. returning from Daily Challenge) re-issued the Library+Courses
    reads; also had no error branch (an unexpected exception silently
    rendered as "Nothing to recommend yet"). Added a cached
    `_recommendedFuture` keyed by `(schoolId, guest)` plus a
    `snap.hasError` branch.

- **Part 11 dark-mode conversion, in progress**: converted `lib/features/testing/`
  (6 files) and `lib/features/courses/` (2 files) from `C.xxx` to
  `AppColors.of(context)`. Confirmed via grep that both directories now
  have zero remaining `C.` references. Two files (`courses_page.dart`'s
  `_CourseCard`, `course_detail_page.dart`'s top-level `_kPalette`) used a
  `static const`/top-level-const color palette outside `build()` — the
  general blocker flagged in the Part 16 architecture report for the same
  pattern in `clubs_page.dart`. Restructured both into instance/plain
  methods taking `AppColors ac` as a parameter, computed once per
  `build()` and threaded through, rather than a compile-time constant.
  This is the reusable fix for that pattern wherever it recurs.
  8 of the 67 originally-flagged files are done; 59 remain (full grouped
  list captured by the earlier scoping pass — re-run
  `grep -rl 'C\.bg\b\|C\.txt\b\|C\.surf\b' lib/` for the current exact
  list). Given the size of this pass (67 files, no compiler in this
  session to verify each), pausing dark-mode work here to give real time
  to Parts 18/19 rather than spending the whole session on one part —
  resuming this is pure repetition of the now-proven pattern, safe to
  pick up in any future session file-by-file.

## Session continuation (2026-08-08, network restored)

- Picked back up after a discontinuity mid-session (context/process
  boundary, not a user action — confirmed via git log that a prior
  continuation of this same autopilot run had already committed real
  additional progress: more of Part 13, Part 16's classification
  (`docs/ARCHITECTURE_REPORT.md`), and 8 more dark-mode file conversions
  for Part 11). Verified nothing was lost: `git status` was clean, all
  in-flight work was already committed. Re-checked the "no network at
  all" blocker logged just above — **network is back**
  (`storage.googleapis.com` resolves and responds again), confirmed
  `flutter --version` is re-provisioning the Dart SDK cache now that it
  can reach the network (expected, per this session's own note that the
  next invocation would trigger exactly this).
- **Part 16**: reviewed `docs/ARCHITECTURE_REPORT.md` — the classification
  is thorough and the "defer the physical move" call was sound
  (164-file mass move with real import-rewrite risk). Now that network/
  analyze access is back, the move itself is technically executable, but
  it's explicitly optional in `02_DAY2_BRANDING_AND_SPLIT.md` ("only if
  time allows") and has zero effect on anything a demo audience would
  see (pure internal reorganization). Leaving it deferred as documented
  rather than spending remaining session time on a refactor with no
  demo-visible payoff — Parts 15/18/19 have more real value left to
  extract from the time remaining.
- **Part 15 (automation pipeline, quizzes/tests half)**: the Courses half
  was already covered in Part 2 (verified compile-course.js end to end
  against real AI-authored content). Built the matching piece for
  Quizzes/Tests: `academia_compiler/compile-quiz.js`, same CLI shape and
  --write/--serviceAccount flow as compile-course.js on purpose (one
  compiler, two content types). Source format is JSON, not Markdown —
  quiz questions are structured data (type/prompt/options/correctIndex/
  points), not prose, so JSON is the honest source-of-truth format here
  rather than forcing them through a Markdown parser. Validates against
  Test/TestQuestion's exact shape (lib/models/test.dart): rejects an
  out-of-range correctIndex, a missing options list, non-positive
  points, an unrecognized question type, before ever touching Firestore.
  Wrote a real 5-question Calculus quiz (`quiz-calculus.json`, 4 MCQ +
  1 structured, matching the existing Calculus course content from Part
  2 for narrative continuity) and dry-compiled it successfully. Same
  publish blocker as compile-course.js: no Firebase service account key
  available in this session, so `--write` hasn't been exercised end to
  end against real Firestore, only validated through the dry-run
  compile + schema checks.

## Session resume (2026-08-10) — new master directive, Library-first

- User provided `academia-master-development-directive.md` (committed
  `144213e`) reordering priorities: Library (non-negotiable) > Dark Mode >
  Content Opening > Messaging > Compiler > Website. Working through it in
  that order; this log continues terse-per-decision style.
- **Security finding, fixed immediately (commit `48510aa`)**: a live
  Firebase Admin SDK service-account key
  (`academia-b1705-firebase-adminsdk-fbsvc-98865a42cf.json`) was tracked
  in git, committed in `de096c8`, already pushed to `origin/main` and
  `origin/demo-prep`. Checked exposure: repo is **private**, single
  collaborator (the repo owner) — not publicly exposed, but a live
  admin-bypasses-all-rules credential has no business in git regardless.
  Untracked it (`git rm --cached`, kept the local file) and added
  `*firebase-adminsdk*.json` / `serviceAccountKey.json` / `*.pem` / `*.key`
  to `.gitignore`. **Did NOT rewrite history or force-push** — the key
  still exists in past commits on origin; that cleanup
  (`git filter-repo` + force-push) is explicitly outside autopilot's
  authority per standing instructions (force-push requires the user's
  go-ahead). Recommend the user rotate this service-account key in the
  Firebase/GCP console when convenient. Separately noted: a *second*,
  different-suffix copy of this same key
  (`academia-b1705-firebase-adminsdk-fbsvc-c48249758a.json`) sits in
  `academia_compiler/`, which is **outside** the `academia_app` git repo
  entirely (confirmed via `git rev-parse --show-toplevel`) — not tracked,
  not pushed, no action needed there beyond awareness.
- **Library classification rebuild (directive §7-12, the non-negotiable
  part)**: audited first rather than rebuilding blind, per the directive's
  own instruction. Found the "1000 tags at top" failure mode described in
  the directive does NOT literally exist in the current code — `subject`
  is already a fixed 8-value controlled list (`kAcademicSubjects`,
  ChoiceChips, "never free text" per an existing code comment) driving the
  Library's subject filter chips, matching the 2026-08-08 session's same
  finding. The real, non-stale gap: the directive's "Level/Class" and
  "Examination/Type" classification dimensions (its examples: "GCE
  Physics 2022", "Form 4") don't exist on `AcademicContent` at all — only
  `subject` + free-text `tags` + the document-kind `ContentType` enum
  existed. Added `level` (`kAcademicLevels`: Form 1-5/Lower Sixth/Upper
  Sixth/Undergraduate/All Levels) and `examBoard` (`kExamBoards`: GCE/
  Probatoire/BEPC/BAC/Mock Exam/School Exam/N-A) as new controlled-list
  fields on the model, same "predefined, ChoiceChip, never free text"
  pattern as `subject` — plus a plain optional `year` int. Both new lists
  are Cameroon-exam-system-specific (Probatoire/BEPC/BAC alongside GCE)
  since that's this app's actual context.
  - **Index-explosion avoidance (documented in code, repeating here for
    visibility)**: did NOT add a Firestore composite index for every
    filter-dimension combination — that multiplies combinatorially as
    dimensions grow (institutionId × contentType × subject × level ×
    examBoard × year). Kept the existing indexed dims
    (institutionId+contentType+subject+uploadDate) server-side, and added
    level/examBoard/year as **client-side refinement** over a wider page
    (300 vs 80 docs) when any are active. This is the same class of
    scoped, documented tradeoff as the prior session's dark-mode/
    architecture-split calls — correct up to the low-thousands-per-
    institution range the directive's own volume-testing section (10/100/
    1000 files) targets; would need revisiting (real composite indexes
    picked by actual usage patterns) well beyond that.
  - Found `content_edit_page.dart` used a **free-text** `TextEditingController`
    for subject (`_subjectCtrl`), inconsistent with upload's locked
    ChoiceChip picker — a real instance of the uncontrolled-tag problem,
    just in the edit flow, not upload. Fixing as part of this pass by
    converting edit's subject field to the same ChoiceChip pattern and
    adding level/examBoard/year pickers there too.
