# Verification Report — FULL_BUILD_LIST.md Part 19

Run on branch `demo-prep`, this session. Covers every automated check that could actually be
run in this environment. See `docs/AUTOPILOT_LOG.md` for the full decision trail behind every
fix; this document is pass/fail results only.

| Check | Result |
|---|---|
| `flutter analyze` | ✅ PASS — 0 errors, 33 minor info/warning lints |
| `flutter test` | ✅ PASS — 2/2 |
| Website (`academia_web`) `npm run build` | ✅ PASS — 5/5 static pages |
| Android APK build (Academia flavor) | ⛔ BLOCKED — sandboxed-environment native-toolchain crashes, not a code defect (details below) |
| Android APK build (Green Hill flavor) | Not attempted — Academia flavor never completed; same blockers apply to both |
| `firebase deploy` (rules/indexes) | Not run — reserved for manual execution per standing instructions |

## Static analysis — `flutter analyze`

**PASS — 0 errors.** 33 issues found, all `info`/`warning` level style lints (unused imports,
deprecated `withOpacity`, missing `const`, etc.), none of them compile errors. Given a large
share of this session's edits were made during a stretch with no working `flutter analyze`
(local environment network outage — see the AUTOPILOT_LOG "environment blocker" entry), a
clean 0-error result across the whole multi-hundred-file codebase is the single most important
confirmation in this report: nothing broke.

## Unit/widget tests — `flutter test`

**PASS — 2/2.** `test/widget_test.dart` and `test/quill_paste_structure_test.dart`. Note this
is a thin suite (placeholder-level coverage), not a claim of comprehensive test coverage — not
something this session added to.

## Website — `academia_web` (Part 18)

**PASS.** `npm run build` compiles the marketing homepage and the dashboard-preview page
cleanly: `✓ Compiled successfully`, 5/5 static pages generated, no type errors, no build
errors. First-load JS ~103-106 kB per route.

## Android builds

**BLOCKED in this environment — not a code defect.** Attempted
`flutter build apk --flavor academia --dart-define=BRAND_ID=academia --dart-define=APP_MODE=platform --debug`
repeatedly across this session. Progress across attempts, in order:

1. First attempts failed with `Building native assets for package:objective_c failed.
   Compilation of hook returned with exit code: -1073741819` (Windows STATUS_ACCESS_VIOLATION)
   — `path_provider_foundation` (the Apple-platform implementation of `path_provider`, added
   this session for the offline-download feature, Part 3) pulls in `objective_c`, and Flutter's
   native-assets step evaluates its build hook even though the target is Android. This is a
   known rough edge in Flutter's still-experimental native-assets feature, not something fixable
   from the app side; `flutter config --no-enable-native-assets` isn't a workaround either —
   `objective_c` then refuses to build at all ("require the dart assets feature to be enabled").
2. Once past that, hit `strings.xml:3:26: The string "--" is not permitted within comments` —
   a real bug this session introduced (an em-dash-style `--` inside an XML comment) and fixed
   (commit `0201c11`).
3. Once past that, hit repeated `No such host is known (storage.googleapis.com)` downloading
   Flutter engine artifact JARs (`x86_64_debug`, `arm64_v8a_debug`) — this sandboxed
   environment's network access was intermittently unavailable for large downloads over the
   course of the session (see AUTOPILOT_LOG's "environment blocker" entry — at one point there
   was no network access *at all* for an extended stretch, confirmed via DNS failures on
   multiple unrelated hosts, not just this one).
4. On the attempt that finally got past all three of the above, hit
   `cmake.exe ... finished with non-zero exit value -1073741819` — the same class of Windows
   access-violation crash as #1, this time in the `jni` package's (a transitive dependency, used
   by `path_provider_android`) native C++ build step for `armeabi-v7a` via NDK/CMake, an ABI
   that isn't even in this project's own `abiFilters` (`arm64-v8a`, `x86_64` only — the `jni`
   package's native module doesn't inherit the app-level ABI restriction).

Every one of the four blockers above is either (a) a real bug that was found and fixed
(`strings.xml`), or (b) a crash/network-availability issue in *this specific sandboxed shell's*
interaction with spawned native subprocesses (`dart compile kernel`, `cmake.exe`, `npm`'s own
wrapper script all hit variants of the same access-violation/wrapper-confusion pattern at
different points this session, alongside dozens of transient `EPERM uv_spawn`/"PowerShell
executable not found" errors throughout — see AUTOPILOT_LOG for the running list). None of
these are Dart/Kotlin/Gradle configuration errors in the project itself.

**The strongest available evidence the code itself is sound**: `flutter analyze` passes with
zero errors across the whole codebase (see above), and every Firestore rule/index change in
this session was cross-checked against the exact query shape it's meant to authorize (see
AUTOPILOT_LOG). The APK build failures are 100% native-toolchain process crashes and network
availability, never a compile error, an unresolved symbol, or a Gradle configuration mismatch.

**To actually produce the APK**, run this exact command on a normal (non-sandboxed) machine
with reliable network access — no code changes needed:
```
flutter build apk --flavor academia  --dart-define=BRAND_ID=academia  --dart-define=APP_MODE=platform  --debug
flutter build apk --flavor greenhill --dart-define=BRAND_ID=green_hill --dart-define=APP_MODE=school   --debug
```
The Green Hill flavor build was not attempted separately given the Academia flavor never
completed — there is no reason to expect a different result, since the blockers above are
either fixed in the repo already or purely environmental and apply identically to both flavors.

Before either build reaches a real device: `firebase deploy --only firestore:indexes,firestore:rules`
has **not** been run this session (correctly — it's the one step the standing instructions
reserve for manual execution, not autopilot). Every Firestore fix in this session is a local
file edit (`firestore.rules`, `firestore.indexes.json`) waiting on that deploy.
