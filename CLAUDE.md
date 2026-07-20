# Academia — Claude Code project notes

Flutter app (Material 3, Firebase, Provider). `lib/` layout:

- `core/` — shared primitives (`Result<T>` sealed class for success/failure,
  `docx_parser.dart`, `debouncer.dart`, `constants.dart`)
- `theme/` — single source of truth for colours/typography. Colour tokens
  live in the `C` class (`theme/app_theme.dart`). `theme/app_colors.dart`
  is a separate, intentional dark-mode `ThemeExtension` — additive, not a
  duplicate (see its own header comment: `C` stays untouched on purpose
  because it's used in hundreds of `const` constructors). Currently wired
  into Home only.
- `models/` — plain data classes, aggregated via `models/models.dart`
- `repositories/` — data access, return `Result<T>`, not raw exceptions.
  Every Firestore/Storage write needs a `.timeout(...)` — a missing one
  on a stalled connection looks exactly like a frozen button and cost
  real debugging time to trace once already.
- `services/` — cross-cutting singletons (analytics, auth, config, crash reporting)
- `providers/` — `ChangeNotifier` app state
- `screens/` — top-level routing/auth screens
- `features/<n>/` — one folder per feature, each with a barrel file
  (e.g. `features/academic_content/academic_content.dart`)
- `widgets/` — shared widgets, aggregated via `widgets/widgets.dart`.
  `widgets/app_background.dart` is the shared gradient-background wrapper
  every content page's Scaffold body should use — see "known gotchas" below.
- `pages/` — legacy/misc standalone pages not yet moved into `features/`

## Conventions already in use — follow them, don't invent new patterns
- Repositories/services return `Result<T>` (`core/result.dart`); UI checks
  `is Success<T>` / `is Failure<T>`, never throws for expected failure paths.
- Barrel files (`x/x.dart`) re-export a folder's public API — update them
  when adding/removing a file in that folder.
- Colour/spacing/typography come from `theme/`, not literals.
- `main.dart` wires global error handling through `runZonedGuarded` +
  `FlutterError.onError` + Crashlytics — don't bypass it with stray
  `try/catch` that swallows errors silently.
- Bottom nav is fixed: Home, Library, Magazine, Courses, Profile — same
  for every account type. Do not add per-feature tabs back.
- Shared engagement logic (like/bookmark toggling) lives in
  `repositories/engagement_helper.dart` — reuse it for new content types.
- No fabricated/hardcoded data or fake stats, ever — a hardcoded "3"
  notification badge and a fake quiz card were both found and removed
  for exactly this reason during earlier passes on this project.

## Known gotchas (do not rediscover these the hard way)
- `flutter_quill` toolbar widgets require `FlutterQuillLocalizations.delegate`
  registered in MaterialApp's `localizationsDelegates`. If missing, any
  screen with a Quill toolbar throws on first build, in a tight loop,
  with zero visible symptom other than "the button does nothing." This
  is fixed in main.dart already — if this exact symptom reappears, check
  that fix wasn't reverted before doing anything else.
- `share_plus` is pinned to `^9.0.0` on this project — use
  `Share.share(text)`, NOT the newer `SharePlus.instance.share(ShareParams(...))`
  API from later major versions.
- Any Firestore query combining `.where(fieldA)` with `.orderBy(fieldB)`
  on a different field needs a composite index (`firestore.indexes.json`),
  or the stream throws `FAILED_PRECONDITION`. If the calling StreamBuilder
  doesn't check `snapshot.hasError`, this looks exactly like "the list is
  just empty" — always check hasError before concluding a query is wrong.
- `flutter`/`dart` may not resolve on PATH inside a restricted Claude
  Code shell even when they work fine in a normal terminal — resolve the
  full path first if bare commands fail.
- `flutter analyze`/`flutter build` can hit a hard "requires approval"
  wall in an unattended `-p` session regardless of `--allowedTools`
  patterns. Fix: unattended sessions use `--dangerously-skip-permissions`.
- Automated find-and-wrap edits (e.g. wrapping every Scaffold body in a
  shared widget) are risky when a file has a variable, field, or ternary
  ALSO named/shaped like the target pattern (e.g. `body:` matching an
  `Announcement.body` string field before the real Scaffold's `body:`).
  Balanced parens after an edit does NOT mean the edit landed in the
  right place — verify by reading the actual diff context, not just a
  paren-count check, especially for ternary expressions (`x ? A : B`)
  where naive first-paren-matching grabs only the first branch.

## House rules for this polishing pass
1. One task from `polish/TASKS.md` per commit. Small, reviewable diffs.
2. Never change public widget/API signatures used across files without
   grepping for all call sites first and updating them in the same commit.
3. Run `dart format .` and `flutter analyze` before considering a task done;
   a task isn't complete if analyze introduces new warnings.
4. Don't touch generated files, `pubspec.lock`, or anything under `build/`.
5. If a task turns out to be bigger than one commit, split it into
   sub-checkboxes in `polish/TASKS.md` instead of doing a giant diff.
6. No behavior changes disguised as "polish" — refactors must be
   functionally identical unless the task explicitly says otherwise.
7. Never stop and wait for input mid-task in an unattended run. If
   something needs a live device, a design decision, or credentials —
   skip it, log one line to `polish/logs/` or REPORT.md, and move on.
8. Prefer honest partial completion over claiming something is done
   without `flutter analyze` actually confirming it.
