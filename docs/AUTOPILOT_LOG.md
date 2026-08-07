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
