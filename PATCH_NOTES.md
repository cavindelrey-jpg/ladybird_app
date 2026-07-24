# PATCH NOTES — Testing, Quiz & XP System

## Before anything else: a pre-existing bug this patch fixes

Your codebase had **two disconnected XP systems** already:

1. `XpRepository.awardXp()` — transactional, capped at 200 XP/day, logged
   to `xpTransactions`. Fully built, but nothing called it.
2. `AuthService.addXp()` — wrote straight to a separate `xpTotal` field.
   No cap, no ledger. This is what magazine reads and the Daily
   Challenge actually used.

They could silently drift apart — a "Total XP" dashboard built on top of
either one alone would have been showing an incomplete number. Fixed by
making `XpRepository` the single source of truth and having
`AuthService.addXp()` delegate to it. `AppUser.xpTotal` is left in the
model (so old stored data doesn't vanish) but is no longer written to or
read from anywhere — see the file comment in `xp_transaction.dart`.

Also found two **dead buttons** on Home: the "Quizzes" quick-access tile
opened a `ComingSoonPage`, and the XP/streak stat card showed a
chevron (implying it's tappable) with no `onTap` at all. Both wired up
below.

One more pre-existing thing worth knowing about, not touched by this
patch: `StreakRepository` (`activityDays` subcollection) exists in the
repo but is never called from anywhere — the streak that's actually live
on Home is `AuthService.recordDailyActivity()` writing directly to
`AppUser.streakDays`/`lastActiveDate`/`weekActivityDates`. This patch
builds streak XP on top of the **live** system, not the orphaned one.
Worth deleting `StreakRepository` in a future cleanup pass so there
aren't two streak implementations sitting side by side.

## New files

- `lib/models/test.dart` — `Test` / `TestQuestion` / `QuestionType`
  (mcq / structured / longForm) / `TestDifficulty`. A single test can mix
  all three question formats. Questions are embedded in the test doc
  (same pattern as `DailyChallenge`), not a subcollection — one read per
  test regardless of question count.
- `lib/models/test_attempt.dart` — `TestAttempt` / `QuestionResponse`.
  The grading framework: MCQ is graded instantly; structured/long-form
  start ungraded (`pointsAwarded: null`) and wait for
  `TestRepository.gradeResponse()`.
- `lib/core/xp_rules.dart` — every XP formula, in one place, all pure
  functions (no Firestore calls) so they're easy to tune or unit-test:
  - `questionXp()` — flat per-format rate (MCQ 10 / Structural 25 /
    Long-form 45, your already-decided rates) × difficulty multiplier ×
    correctness ratio.
  - `completionBonusXp()` — one-time bonus when a test is fully graded,
    tiered by score (40–59%→5%, 60–79%→15%, 80–99%→30%, 100%→50% of the
    XP already earned on that attempt).
  - `difficultyMultiplierPercent()` — easy 100% / medium 115% / hard 130%.
  - `kStreakDailyXp` (5) + `streakMilestoneBonusXp()` — every 7th day:
    50, 100, 150, 200... (formula, not a table, so it never runs out).
  - `levelForXp()` / `levelProgress()` — level curve for the dashboard,
    also formula-based (100×L XP to clear level L).
- `lib/repositories/test_repository.dart` — subject-based test CRUD,
  `submitAttempt()` (auto-grades MCQ, stores the rest pending),
  `gradeResponse()` (manual grading, awards XP, triggers the completion
  bonus once the last response is graded), history + grading-queue
  streams.
- UI, all under `lib/features/testing/`:
  - `tests_subject_picker_page.dart` — subject grid with real test counts.
  - `tests_list_page.dart` — tests for one subject.
  - `test_taking_page.dart` — renders MCQ / structured (ruled lines) /
    long-form (labelled sections) in one attempt.
  - `test_result_page.dart` — honest partial result if anything's still
    pending manual grading; per-question XP breakdown.
  - `grading_page.dart` — lecturer/admin queue + per-answer grading UI.
    This is the seam a future AI grader plugs into — same
    `gradeResponse()` call, human-typed score replaced by a model
    suggestion. **No AI grading is wired up yet — this is a real gap,
    flagged rather than faked.**
  - `xp_dashboard_page.dart` — Total XP, level + progress bar, streak +
    week dots, test history, XP earning history. Every number is a live
    stream from a real source (see file comment).

## Modified files

- `models/xp_transaction.dart` — added `testCompletion` / `streakDaily`
  / `streakMilestone` sources, and a generic `refId` field on
  `XpTransaction` (points at the `testAttempts/{id}` that earned it).
- `repositories/xp_repository.dart` — `awardXp()` now accepts optional
  `refId`. No behavior change to the existing cap/transaction logic.
- `services/auth_service.dart` — `recordDailyActivity()` now awards real
  streak XP (once per genuinely-new day, using the existing same-day
  guard — no separate de-dup needed). `addXp()` now requires an
  `XpSource` and delegates to `XpRepository`, returning the amount
  actually awarded (may be less than requested if the daily cap was hit).
- `repositories/magazine_repository.dart` — updated its one `addXp()`
  call site for the new signature (`XpSource.magazineRead`).
- `pages/daily_challenge_page.dart` — same, `XpSource.mcq`, and the
  success message now shows the actually-awarded amount instead of
  assuming the full amount landed.
- `features/dashboard/universal_home_page.dart` — XP stat now reads live
  from `XpRepository.watchBalance()` instead of stale `AppUser.xpTotal`;
  the whole stat card is now tappable → `XpDashboardPage`; "Quizzes"
  quick-access tile → `TestsSubjectPickerPage` instead of `ComingSoonPage`.
- `widgets/app_drawer.dart` — added "Tests & Quizzes" (everyone) and
  "Grading Queue" (lecturer+) entries.
- `core/constants.dart` — added `colTests` / `colTestAttempts`.
- `models/models.dart`, `repositories/repositories.dart` — barrel exports
  for the new files.

## Known gaps / honest scope notes

- **Firestore rules not updated.** `createTest()`/`deleteTest()`/
  `gradeResponse()` have no server-side role check yet — only the UI
  gates them (`AppUser.hasMinRole(UserRole.lecturer)`). Needs a
  `firestore.rules` pass for the new `tests`/`testAttempts` collections
  before this ships, same as any other write path.
- **No test-authoring UI.** `TestRepository.createTest()` is ready, but
  there's no lecturer-facing "build a test" screen yet — tests currently
  have to be created directly in Firestore (or via a future admin
  screen/ingestion pipeline). Flagging this as the next natural piece of
  work, not hiding it behind a fake "coming soon" screen.
- **AI grading**: the `gradeResponse()` seam is ready for it, nothing
  calls an AI model yet.
- Reattempting the same test isn't blocked — the existing 200 XP/day cap
  is what stops it being an infinite-XP farm, same reasoning the
  magazine-read system already used for its own per-read amount.
