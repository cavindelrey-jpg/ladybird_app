# Academia — Project Context for Claude Code

## What this is
Flutter/Firebase educational platform for Cameroonian students (GCE curriculum, FCFA pricing).
Two layers: school/institutional (multi-tenant, scoped by `schoolId`) and independent student layer.

## Stack & conventions (do not deviate without asking)
- Flutter + Firebase (Firestore, Auth, Storage, Analytics, Crashlytics)
- Repository pattern: all repo methods return `Result<T>` (Success/Failure) — never throw raw exceptions up to UI
- Any Firestore/Storage write in a repository MUST have a `.timeout(...)` — a missing timeout on a stalled connection looks exactly like a frozen button, and cost hours to diagnose once already.
- Singleton repositories via `.instance`
- Provider for state management
- All Firestore writes/reads must be scoped by `schoolId` where applicable
- Role gating via `hasMinRole()` across 6 tiers: guest, student, lecturer, departmentAdmin, schoolAdmin, superAdmin
- No fabricated/hardcoded data or fake stats — a hardcoded badge count was found and removed for exactly this reason. Live Firestore data only.
- Bottom nav is fixed: Home, Library, Magazine, Courses, Profile — same for every account type. Do not add per-feature tabs back.
- Shared engagement logic (like/bookmark toggling) lives in `lib/repositories/engagement_helper.dart` — reuse it for new content types instead of copy-pasting the pattern again.

## Design system
- Colors: Navy `#0A1F44`, Gold `#C9A227`, Primary Blue `#1A56DB`, border `#E2E8F0`
- Fonts: `GoogleFonts.sora` (headings), `GoogleFonts.inter` (body)
- Card radius 14–16px
- Shared components: `ACard`, `EmptyState`, `ShimmerCard`, `ErrorView`, `GradientCard`, `UserAvatar` — reuse these, don't create one-off variants
- Give screen headers real top padding (14px+) after SafeArea — 4px was found jammed against the status bar on four different screens.

## Known gotchas (do not rediscover these the hard way)
- `flutter_quill` toolbar widgets require `FlutterQuillLocalizations.delegate` registered in MaterialApp's `localizationsDelegates`. If missing, any screen with a Quill toolbar throws on first build, in a tight loop, with zero visible symptom other than "the button does nothing." This is fixed in main.dart already — if you see this exact symptom again, check that fix wasn't reverted before doing anything else.
- Static code reading cannot catch runtime-only bugs. When something is reported as visually broken and the code "looks correct," verify with `flutter analyze` and, ideally, `flutter build apk --debug` — do not conclude something works from reading alone.
- `share_plus` on this project is pinned to `^9.0.0` — use `Share.share(text)`, NOT the newer `SharePlus.instance.share(ShareParams(...))` API from later major versions.
- Any Firestore query combining `.where(fieldA, ...)` with `.orderBy(fieldB, ...)` on a DIFFERENT field needs a composite index, or the stream throws `FAILED_PRECONDITION`. If the calling StreamBuilder doesn't check `snapshot.hasError`, this looks exactly like "the list is just empty" — always check hasError before concluding a query itself is wrong.
- `flutter`/`dart` may not resolve on PATH inside a restricted Claude Code shell even when they work fine in the human's own terminal — resolve the full executable path first (e.g. `where flutter`) before relying on bare commands in an unattended session. Separately, even once the path resolves, invoking the `flutter` binary itself (any subcommand — `analyze`, `--version`, etc., via Bash or PowerShell) can require an interactive tool-use approval that never arrives in an unattended/loop session — this is a distinct blocker from PATH resolution and isn't fixable by finding a different path or shell; treat it the same as a missing live device (log it, don't retry-loop on it).

## Rules for any unattended/loop session
- Never run `git push` or `firebase deploy` automatically without it being an explicit step the human asked for — this project's workflow does expect commits per checkpoint, but confirm scope first if unsure.
- Never stop and wait for input mid-task. If something needs a live device, a design decision, or credentials only the human has — skip it, log one line to REPORT.md, and move on immediately.
- Never delete or overwrite files outside `lib/`/`android/` structure without explaining why first.
- When fixing analyze/build errors, prefer the smallest change that fixes the root cause over restructuring working code.
- If the same error persists after 2 attempts, stop and describe what's blocking it instead of continuing to guess.
- Prefer honest partial completion over claiming something is "production ready" or "fully implemented" when it hasn't been verified by an actual build/analyze pass.
