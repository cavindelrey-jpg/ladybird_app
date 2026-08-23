# Test Plan — Green Hills App

## Critical constraint (read this first)

**There is no Flutter SDK in this environment**, and disk space is too tight (2.5GB free on a 111GB disk) to safely install one. Every test in this plan — new and pre-existing — was written or read **without being executed**. This plan and the accompanying `TEST_REPORT.md` describe what was written and why, not verified pass/fail results, coverage numbers, or mutation-testing output, because none of those tools were available to run.

This is a real deviation from the brief's TDD loop (write failing test → confirm it fails → fix → confirm it passes → run full suite) — that loop requires execution at every step, which isn't possible here. Where a genuine defect was found by reading the code, it's documented as a test that asserts the *actual current behavior* (so it should pass once run, and would catch a regression if that behavior later changes), with an explicit comment explaining why the behavior is surprising, rather than a red-then-green cycle I can't perform.

**Action needed from you:** run `flutter test` (or push to the branch and let Codemagic's own `flutter test` step run it) and paste the output back. Earlier this session, exactly this loop — write blind, you run `flutter analyze` via Codemagic, paste the output, I fix what's actually broken — caught one real bug in ~40 changed files. I'd expect the same pattern to work here.

## Architecture overview (relevant to testing)

This is a Flutter + Firebase app (Firestore, Storage, Cloud Functions). The existing test suite (`test/*_test.dart`) is 100% pure-Dart logic tests — no `fake_cloud_firestore`, no `mockito`/`mocktail` (neither is a pubspec dependency), no widget tests beyond a placeholder. That's a deliberate ceiling, not an oversight: anything touching Firestore, Storage, or the widget tree needs either a Firebase emulator or a mocking layer this project doesn't have set up, and standing one up wasn't attempted here (see "Remaining gaps" below) since it would be entirely unverifiable in this sandbox anyway.

Given that ceiling, this pass focused on **pure business-logic modules with zero external dependencies** — the same category the existing 5 test files already cover — since that's where new tests can be written with real confidence of correctness even without execution.

## Components inspected and their priority

| Component | Responsibility | Priority | Status |
|---|---|---|---|
| `lib/core/xp_rules.dart` | Entire XP economy: per-question XP, completion bonuses, streak milestones, level curve, past-paper pricing | **Critical** | **Newly tested** (was 0% covered) |
| `lib/core/feature_access.dart` | Single authoritative paywall/entitlement gate for every premium feature | **Critical** | **Newly tested** (was 0% covered) |
| `lib/core/essay_matching.dart` | Structured/essay answer auto-grading | Critical | Already tested (`essay_matching_test.dart`) |
| structured-answer matching logic | Auto-grading for structured questions | Critical | Already tested (`structured_matching_test.dart`) |
| `RecommendationRepository.rankSubjectsByUsage` | Contextual content recommendation ranking | High | Already tested (`recommendation_ranking_test.dart`) |
| `universal_home_page.dart: rankHomeSubjectsByUsage` | Home's own recommendation ranking (deliberately separate from the above) | High | Already tested (`home_recommendation_ranking_test.dart`) |
| Quill paste-structure parsing | Rich-text paste import | Medium | Already tested (`quill_paste_structure_test.dart`) |
| `lib/models/entitlement.dart` (`Entitlement.isActive`/`isExpired`/etc.) | Time-based premium-access evaluation | Critical | Exercised indirectly via `feature_access_test.dart` fixtures; not tested in isolation (see gaps) |
| Every repository (`lib/repositories/*.dart`) | Firestore reads/writes, business rules mixed with I/O | Critical | **Not unit-tested** — needs a Firestore emulator/fake, out of reach here |
| Every widget/page (`lib/features/**`, `lib/screens/*.dart`, `lib/widgets/*.dart`) | UI | Varies | **Not tested** — needs `flutter test` execution, out of reach here |
| `lib/core/docx_parser.dart`, `lib/theme/club_visuals.dart` (fallback icon selection), `lib/core/debouncer.dart` | Smaller pure-ish utilities | Low-Medium | Not tested this pass — see "Remaining gaps" |
| `functions/*.js` (Cloud Functions) | Server-side XP enforcement, serial claiming, PDF ingest pipeline | High | Reviewed during the earlier security pass this session, not unit-tested (Node/Jest, different toolchain, out of scope for a Dart `test/` pass) |

## Behaviors tested (new coverage)

### `xp_rules.dart` (`test/xp_rules_test.dart`)
- `difficultyMultiplierPercent` — all 3 enum values.
- `academicTierFor` — every real dropdown value, unrecognized/empty fallback, **and a case/whitespace-sensitivity check that demonstrates a real (if minor) gap**: `'form 4'` (lowercase) silently resolves to the *lowest* tier instead of throwing or matching, because the mapping is an exact-string switch with no normalization.
- `academicLevelMultiplier`, `quizDailyXpCapForLevel`, `pastPaperPriceForContentLevel`, `pastPaperPackPriceForContentLevel` — value tables + fallback-direction checks (under-charging is the safe default, verified explicitly).
- `xpSourceForQuestionType` — exhaustive mapping.
- `questionXp` — full marks, zero marks, `maxPoints <= 0` (division-by-zero guard), over-awarded points (clamping), negative points (clamping), compounded difficulty×level multipliers (hand-verified arithmetic), partial credit, **and a documented gap: a negative `levelMultiplier` isn't validated and produces negative XP** (mitigated downstream by `XpRepository.awardXp`'s `rawAmount <= 0` no-op guard, but not validated at the source).
- `baseXpAtLevel`, `minimumCompletionFloor` — including empty list, single element, and a 5,000-element list (large-collection boundary).
- `attemptCooldownMultiplier` — every step (0, negative, 1, 2, large) of the anti-farming cooldown.
- `completionBonusXp` — every score tier boundary (exactly 40/59.9/60/79.9/80/99.9/100), zero-XP-earned edge case, negative XP-earned edge case, out-of-range score (>100%), **and a real discovered defect: `scorePercent: double.nan` silently falls through every comparison (IEEE754: all NaN comparisons are false) and lands in the lowest bonus tier instead of being rejected.** This can only occur from a 0/0 division bug upstream, but if it ever does, this pays out a bonus for a NaN score instead of erroring — documented via a test asserting the actual (surprising) behavior.
- `streakMilestoneBonusXp` — every non-milestone day in a range, zero/negative, every real milestone (7/14/21/28), and a very long streak (7,000 days) to confirm the formula never runs out.
- `xpRequiredForLevel` — level 1/0/negative, first several levels by hand-verified value, and a monotonicity property test (level 1-100, strictly increasing).
- `levelForXp` — the most complex function in the file (float estimate + two correction loops). Tested with **a round-trip property across levels 1-200**: for every level, the XP exactly at its threshold must resolve back to that level, and one XP less must resolve to the level below. This is the real correctness proof, not just spot values. Also tested at 50,000,000 XP to confirm the correction loop still terminates and lands correctly for large inputs.
- `levelProgress` — zero XP, an invariant that `into` is always `< span` across a spread of values, and an algebraic reconstruction check (`floor + into == original XP`).

### `feature_access.dart` (`test/feature_access_test.dart`)
Combinatorial: every account state (guest, free, active silver, **expired** silver, active gold, perpetual gold, **expired** gold) against every `FeatureAccessLevel` the registry defines (free, authenticated, silver, gold, unavailable):
- Free features open to everyone including a signed-out guest.
- `null` user treated identically to explicit `AppUser.guest()`.
- Authenticated features: guest blocked, every signed-in tier (even plain free) allowed.
- Gold-only features: guest/free/silver all blocked (**explicitly verifying Silver does NOT satisfy a Gold gate** — the exact "second, slightly different copy of the tier check" class of bug the file's own header comment warns against), expired silver/gold blocked, active or perpetual (no-expiry) gold allowed.
- **A boundary case the code comment implies but doesn't explicitly guard**: an entitlement expiring at exactly the current instant — verified it's already treated as inactive (`isAfter`, not `isAfter-or-equal`).
- Unavailable (role-gated) features: default-closed for every tier including gold, by design.
- `reasonBlocked`: correct copy for each block reason, and specifically that the Gold-specific upsell ("...need Premium Gold...") only appears for a Silver user (who's one tier away), not a plain free user (who'd get the generic upgrade prompt) — and that a role-gated feature's message never implies "upgrading" would help.

## Important invariants tested
- `xpRequiredForLevel` is strictly increasing (no level ever costs less than the one before it).
- `levelForXp` / `xpRequiredForLevel` round-trip exactly at every threshold, for 200 levels.
- `levelProgress.into` is always in `[0, span)` — a progress bar built on this can never show >100% or negative progress.
- `FeatureAccess`: Gold is always a superset of Silver access; an unavailable feature is never accidentally opened by any entitlement tier.

## Known risks / gaps NOT covered this pass
- **Everything Firestore-backed** (all `lib/repositories/*.dart`) — business rules here (e.g. the attempt-cooldown query in `TestRepository`, XP-award transactions) are mixed with I/O and need a Firestore emulator or `fake_cloud_firestore` to test in isolation. Flagging one specific risk noticed while reading `TestRepository`'s cooldown logic: it reads `priorAttemptsInWindow` via a plain query (not inside the same transaction as the eventual write) — two rapid concurrent submissions of the same test could both read the same "prior attempt count" before either writes, both qualifying for a better cooldown multiplier than they should. Not verified as an actual bug (would need a live/emulated Firestore to reproduce), just surfaced as a real risk worth a targeted integration test once emulator infrastructure exists.
- **All widgets/pages** — need `flutter test`/`flutter test --coverage` execution, unavailable here.
- **`Entitlement` model itself** — exercised indirectly through the `feature_access_test.dart` fixtures (active/expired silver/gold, perpetual gold) but has no dedicated unit test file of its own for `isExpired`, `includesVideoCourses`, `daysRemaining` in isolation.
- **`functions/*.js`** — reviewed for security in an earlier pass this session (see `pentest_report.md`), not unit-tested here (different toolchain — Node/Jest — out of scope for this Dart-focused pass).
- **Property-based/generative testing** — the brief asks for this where the project's ecosystem supports it; no property-testing package (e.g. `glados`, `dart_check`) is a pubspec dependency, so the round-trip/invariant tests above were hand-written as targeted range/boundary sweeps instead of true generative testing, per the brief's own instruction not to introduce a new framework unnecessarily.
- **Mutation testing** — no mutation-testing tool available/run. Not attempted.

## Refactors performed
None. Per the brief's own guidance ("make the smallest safe change... preserve observable behavior"), and given zero ability to run the full suite after a refactor to confirm nothing broke, no production code was refactored in this pass — only two new test files were added, plus documentation of two discovered edge-case behaviors (not fixed, since both already have a downstream safety net and fixing pure-calculation code blind, without being able to re-run the suite afterward, carries more risk than it resolves right now).
