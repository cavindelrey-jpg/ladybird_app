# Quiz, Testing & XP system — real feature build

This is NOT a bug-fix list — it's new feature work. Much of the XP
plumbing already exists (XpRepository, transactions, daily caps,
streak system) with exactly ONE working earn-source (Magazine reads).
The quiz/test system itself does not exist anywhere in this codebase —
confirmed multiple times across this project's history. Build it in
the phases below, in order — do not attempt everything in one commit,
and do not move to a later phase until the previous one analyzes clean
and has a real, working (not stubbed) piece of functionality.

Run with: .\polish-loop.ps1 -TasksFile polish/TASKS_QUIZ_XP.md

## Phase 1 — Data model (foundation, do first)
- [ ] Design and add models for: Subject (if not already covered by an
      existing model — check `models/` first), Test (belongs to a
      subject, has a list of Questions), Question (needs a `type` field:
      mcq / structured / longForm), and a per-user TestAttempt/Result
      record. Follow the existing `Result<T>` repository pattern — check
      an existing model like `MagazineArticle` or `PublicCourse` for the
      established style (toFirestore/fromFirestore, mutable working
      fields for composers) before inventing a new style.
- [ ] Add a `TestRepository` (or similar) following the existing
      repository pattern exactly (Result<T>, timeouts on writes, real
      Firestore streams) — check `magazine_repository.dart` as the
      reference implementation for conventions.

## Phase 2 — MCQ (simplest question type, build and verify before continuing)
- [ ] Build MCQ question authoring (in whatever composer/admin surface
      makes sense given the existing app structure — check how course
      content gets created for a precedent) and MCQ taking + automatic
      grading (compare selected option to correct answer).
- [ ] Wire MCQ completion to award real XP via the EXISTING
      `XpRepository.awardXp()` — this method already exists and works,
      it just has never had a caller for quizzes. Do not build a new XP
      award mechanism; use the existing one.

## Phase 3 — Structured questions
- [ ] Build structured-question authoring and answering (multi-line/
      multi-section answer areas). Grading: build a real manual-review
      queue (a teacher/admin marks it correct/incorrect/partial) rather
      than fabricating automatic grading for free-text content — note
      "future AI evaluation" as a documented extension point in a code
      comment, not as something actually implemented this pass.

## Phase 4 — Long-form questions
- [ ] Build long-form answer submission (summary + methodology/steps
      fields, structured per the original spec — math/science gets
      calculation-steps fields, theory subjects get outline fields).
      Same manual-review grading approach as Phase 3.

## Phase 5 — XP rules for tests
- [ ] Define and implement real XP award rules: base XP for completing
      a test, bonus XP scaled to score, bonus for difficulty (test
      needs a difficulty field). Keep the actual numbers simple and
      documented in code comments — this is a game-design decision, not
      something to overthink; a human can tune the numbers later.

## Phase 6 — Magazine publishing XP (real gap, separate from tests)
- [ ] Magazine articles currently award XP only for being READ (already
      working). Add a real XP award when a user's own article gets
      approved/published, using the existing `awardXp()` call — check
      whether an "approval" concept already exists in the Magazine
      publish flow before assuming one needs to be built.

## Phase 7 — Dashboard integration (do last, after the above are real)
- [ ] Surface total XP, current level (derive a simple level formula
      from XP, document the formula in a code comment), streak counter
      (already exists from earlier work — reuse it, don't rebuild),
      test history, and XP earning history on a real dashboard/profile
      surface, using only real data from the phases above — no
      placeholder numbers.

## Rules
- Never stop and wait for input. Skip anything needing a live device,
  design decision, or credentials, log it to REPORT.md, and continue.
- Run `flutter analyze` after each checkbox and fix what it flags.
- One commit per checkbox, not one commit for a whole phase.
- No fabricated grading, XP numbers, or "AI evaluation" that doesn't
  actually exist — if a piece needs a human decision (e.g. exact XP
  values, whether AI grading is in scope), implement the simplest real
  version and document the assumption in a comment, don't fake it.
