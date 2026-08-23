# Test Report — Green Hills App

## Execution status: UNVERIFIED — action needed

No Flutter SDK is available in this environment (confirmed repeatedly this session) and disk space (2.5GB free) is too tight to safely install one. **None of the numbers below are execution-confirmed.** They describe what was written, by careful hand-tracing of the arithmetic against each function's actual source, not a test-runner's output.

**Please run:**
```
flutter test
```
and paste the output back (the same pattern used earlier this session for `flutter analyze`, which caught one real bug this way). I'll fix anything that comes back red.

## Summary

| Metric | Count |
|---|---|
| Test files already present | 6 (`essay_matching_test.dart`, `home_recommendation_ranking_test.dart`, `quill_paste_structure_test.dart`, `recommendation_ranking_test.dart`, `structured_matching_test.dart`, `widget_test.dart`) |
| Test files added this pass | 2 (`xp_rules_test.dart`, `feature_access_test.dart`) |
| Individual `test()` cases added | 67 |
| Tests confirmed passing | **0 — could not execute, see above** |
| Tests confirmed failing | **0 — could not execute, see above** |
| Coverage tooling run | No (`flutter test --coverage` needs the SDK) |
| Mutation testing run | No (no tool available) |
| Flaky tests discovered | None discovered (can't run repeatedly to check) |

## Bugs discovered (by reading, not by a failing test run)

1. **`completionBonusXp` (lib/core/xp_rules.dart) mishandles `NaN` scores.** A `scorePercent` of `NaN` bypasses the `< kMinScoreForBonus` early-return AND every tier `>=` check (IEEE754: all comparisons with NaN are false), falling through to the lowest bonus tier (5%) instead of being rejected. Real-world trigger would be a 0/0 division computing a percentage upstream — not currently known to happen, but not guarded against either. **Not fixed** — documented via `test/xp_rules_test.dart`'s `completionBonusXp` group, asserting the actual current behavior, so this is caught if anyone "fixes" the guard in a way that changes it unexpectedly, and so it's visible to whoever decides whether it's worth guarding against.

2. **`questionXp` (lib/core/xp_rules.dart) doesn't validate `levelMultiplier`.** A negative multiplier produces negative XP. Currently harmless in practice because `XpRepository.awardXp()` treats any `rawAmount <= 0` as a no-op — but that's an incidental downstream protection, not a guarantee at the source. **Not fixed** — documented via a test asserting current behavior, with an explicit comment flagging that a future change to the downstream guard could silently reopen this.

3. **Race condition risk in `TestRepository`'s attempt-cooldown check** (noticed while reading, not while testing — this needs a live/emulated Firestore to actually reproduce, so it's a *suspected* risk, not a confirmed bug): the cooldown multiplier is computed from a plain query read, not inside the same transaction as the eventual attempt write. Two near-simultaneous submissions of the same test by the same user could both read the same "prior attempt count" before either writes its own attempt doc, potentially both qualifying for a better cooldown rate than the rules intend. Logged in `TEST_PLAN.md`'s gaps section as something worth a targeted integration test once Firestore-emulator infrastructure exists — not something I could write a meaningful unit test for without one.

## Existing test suite review (per the brief's "test the tests" section)

Read all 5 pre-existing non-trivial test files. Findings:
- All 5 test pure functions with real assertions against computed values (not mocks, not internal-state peeking) — they match the brief's own "test contracts, not implementation details" guidance already.
- `widget_test.dart` is a placeholder (`expect(true, isTrue)`) — a test that can never fail, exactly the anti-pattern section 7 warns about. Not touched this pass (replacing it meaningfully would mean writing an actual widget test, which needs `flutter test` to write with any confidence and verify — logged as a gap, not silently deleted or "fixed" with another trivial assertion).
- No shared mutable fixtures, no order-dependence, no environment/timezone/filesystem dependence spotted in the 5 real test files — all pure input→output.
- Could not verify these tests "actually detect" a broken implementation (the brief's suggestion to temporarily mutate production code and confirm the test catches it) without being able to run anything.

## Important edge cases covered (new tests)
See `TEST_PLAN.md`'s "Behaviors tested" section for the full breakdown. Highlights:
- Every scoring-tier boundary in the completion-bonus formula (40/59.9/60/79.9/80/99.9/100%).
- A 200-level round-trip correctness proof for the XP level curve (not just spot-checked values).
- A 5,000-element and a 50,000,000-XP boundary to check large-input behavior doesn't degrade or overflow.
- Full entitlement-tier × feature-access-level combinatorial matrix, including expired vs. active vs. perpetual entitlements and the exact-instant expiry boundary.

## Areas still requiring attention (priority order)
1. **Run `flutter test` and report results** — nothing here is trustworthy until that happens.
2. **Firestore-emulator or `fake_cloud_firestore` test infrastructure** — the single biggest coverage gap. Every repository (the actual business-rule-plus-I/O layer) is currently untestable in isolation.
3. **Widget test coverage** — currently effectively zero (one placeholder). Needs `flutter test` available to write with confidence.
4. **The two documented `xp_rules.dart` edge cases** — decide whether they're worth guarding against explicitly (both are currently harmless in practice, but "currently harmless because of an unrelated downstream guard" is a fragile reason to leave a source-level gap).
5. **The suspected `TestRepository` cooldown race** — worth a real investigation with a Firestore emulator; can't be confirmed or ruled out by reading alone.

## Recommended next steps
- Run `flutter test`, paste output back for a real red/green pass.
- If you want deeper coverage of the Firestore-backed repository layer, decide on `fake_cloud_firestore` vs. the Firebase emulator suite as the testing strategy — this is a real infrastructure decision, not something to bolt on blind.
- Consider whether `widget_test.dart`'s placeholder should be replaced with a real smoke test (e.g., app boots to the guest Home screen without throwing) once test execution is available to verify it actually works.
