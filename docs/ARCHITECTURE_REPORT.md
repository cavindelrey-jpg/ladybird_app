# Architecture Split — Extraction Checklist (Part 16)

Status: **classification done, physical file move deferred** (see "Why deferred" below). This
document is the extraction checklist FULL_BUILD_LIST.md Part 16 asks for; treat it as the
work order for whichever session picks up the physical move.

## Why deferred

Part 16 asks to physically move ~164 `.dart` files into `lib/core/`, `lib/shared/`,
`lib/school/` and rewrite every import that touches a moved file. This session has **no
working `flutter analyze`** (the local Dart SDK cache is corrupted and this sandboxed shell
has no network access to re-download it — see `docs/AUTOPILOT_LOG.md`, "environment
blocker" entry). Several files re-export the entire surface of a directory as a barrel file
(`lib/models/models.dart`, `lib/repositories/repositories.dart`, `lib/services/services.dart`,
`lib/widgets/widgets.dart`, `lib/core/core.dart`), which makes import rewrites after a mass
move genuinely easy to get subtly wrong (a barrel file silently re-exporting a moved symbol
from its old path, or a relative import miscount) with no compiler in this session to catch
it. Moving 164 files blind, with the whole app as blast radius, is not a responsible trade
against the value of doing it now vs. once `flutter analyze` works again. Everything below is
safe, compiler-independent prep work instead: classification + a checklist ready to execute
mechanically the moment analyze is available.

## Naming collision to resolve first

`lib/core/` **already exists** — but it's a *technical-utilities* core (`result.dart`,
`docx_parser.dart`, `constants.dart`, `xp_rules.dart`, `debouncer.dart`), not Part 16's
*feature-domain* CORE bucket (Library/Courses/Clubs/Messaging/etc). Reusing the same name for
both would be actively confusing. Recommendation: keep the existing `lib/core/` as-is (it's
SHARED infrastructure regardless of the Part 16 split) and use `lib/shared/`, `lib/school/`,
and a **new** `lib/features_core/` (or just leave feature-domain CORE code where it already
lives under `lib/features/`, and only physically separate SCHOOL-only feature dirs out) —
picking the exact target layout is a judgment call for whoever executes the move; don't
collide with `lib/core/`'s existing meaning.

`lib/config/` (`app_config.dart`, `branding.dart`, Part 17's output) is unambiguously SHARED
infrastructure — no overlap with the CORE/SCHOOL split itself.

## Classification

### CORE (useful without a school — Library, Courses, AI Tutor, Tests/Quizzes, Magazine,
Clubs, Messaging, Profiles, Search)

- `lib/features/library/` (2 files)
- `lib/features/courses/` (2) — **has a `static const` color palette using raw `C.xxx`**,
  same restructuring note as the dark-mode work below; touch once, not twice, if both land
  around the same time.
- `lib/features/courses_marketplace/` (5)
- `lib/features/magazine/` (5)
- `lib/features/clubs/` (4) — same `static const` palette note as above.
- `lib/features/messages/` (3)
- `lib/features/testing/` (6) — Tests/Quizzes
- `lib/pages/search_page.dart`, `lib/pages/bookmarks_page.dart` — CORE, but currently flat
  under `lib/pages/` alongside SCHOOL files (see below), not under `features/`.
- No `features/ai_tutor/` or `features/profiles/` exist yet — AI Tutor isn't built; "Profile"
  today is `lib/pages/profile_page.dart` + `profile_edit_page.dart` (CORE by the spec's own
  list, again flat under `lib/pages/`).

### SCHOOL (Attendance, Timetable, Assignments, Marks, Calendar, Announcements, Dashboard,
Institution/Admin management)

- `lib/features/attendance/` (1), `lib/features/timetable/` (1), `lib/features/assignments/`
  (1), `lib/features/calendar/` (1), `lib/features/announcements/` (3)
- `lib/features/dashboard/` (2) — matches the spec's own SCHOOL example; today it only
  imports `announcement_repository`/`calendar_repository`, so it's cleanly SCHOOL right now,
  but flag as a **future NEEDS-SPLITTING risk**: a real dashboard tends to aggregate CORE
  feeds (courses/library) too as the app grows.
  - Note: `AcademicContentPage`'s own header comment says it "Replaces the old `LibraryPage`"
    — `lib/features/library/library_page.dart`'s `LibraryPage` class is confirmed dead code
    (not referenced from `app_router.dart` or anywhere else; `AcademicContentPage` is what's
    actually routed for "Library"). Worth deleting during the move rather than relocating
    dead code into the new tree — flagging here rather than deleting now, since deletions
    also deserve a compiler check.
- `lib/features/admin/` (3) — institution admin panel/creation + the Part 14 banner CMS
  manager (`hero_slide_manager_page.dart`). The banner CMS itself is arguably SHARED (it
  serves CORE pages' banners too), only the institution-admin pieces are SCHOOL — **NEEDS
  SPLITTING**.
- `lib/features/institution/` (2)
- `lib/features/academic_content/` (5 files: `content_viewer_page.dart`,
  `content_details_page.dart`, `content_edit_page.dart`, `academic_content_page.dart`,
  `content_upload_page.dart`) — not named in either spec bucket. Its model carries an
  `institutionId` field (institution-scoped), but it's what's actually routed as "Library"
  (a CORE feature by name). **Recommend SCHOOL for now given the institution-scoping, but
  flag for a human call** — this is the single biggest classification ambiguity in the
  codebase; get a real answer before moving it rather than guessing silently.
- `lib/pages/marks_page.dart`, `admin_accounts_page.dart` — SCHOOL, flat under `lib/pages/`.

### SHARED (models, repositories, services, utilities, theme, auth, routing, Firebase, shared
widgets)

- `lib/models/` (27 files + `models.dart` barrel)
- `lib/repositories/` (25 + `repositories.dart` barrel)
- `lib/services/` (5 + `services.dart` barrel)
- `lib/widgets/` (11 + `widgets.dart` barrel)
- `lib/theme/` (5, incl. `app_theme.dart`'s legacy `C` constants and `app_colors.dart`'s
  `AppColors`)
- `lib/screens/` (6, incl. `app_router.dart`, `login_screen.dart`, `first_login_screen.dart`)
- `lib/providers/` (4 — organization/institution/theme providers)
- `lib/core/` (5 + `core.dart` barrel — existing technical utilities, unrelated to Part 16's
  CORE bucket, see naming note above)
- `lib/config/` (2 — `app_config.dart`, `branding.dart`)
- `lib/features/onboarding/` (3: `account_choice_screen.dart`, `create_account_screen.dart`,
  `claim_seat_screen.dart`) — pure auth/signup flow, not CORE or SCHOOL per the spec's own
  definitions → SHARED.
- Remaining `lib/pages/*` files not already called out above (`about_academia_page.dart`,
  `notifications_page.dart`, `help_support_page.dart`, `change_password_page.dart`,
  `notification_preferences_page.dart`, `daily_challenge_page.dart`) — settings/account
  scaffolding used regardless of school/no-school → SHARED.

### NEEDS SPLITTING (flagged above, collected here for visibility)

1. `lib/features/admin/` — banner CMS (SHARED-ish/CORE-adjacent) vs. institution admin
   (SCHOOL).
2. `lib/features/academic_content/` vs `lib/features/library/` — get a human decision on
   which one is "real" Library before moving either (the old `LibraryPage` looks safe to
   delete outright, see above).
3. `lib/pages/` as a whole — currently flat and mixes CORE/SCHOOL/SHARED; per-file
   classification above should be treated as the source of truth once the move starts, not
   the directory name.

## Execution order recommended for whoever runs the physical move

1. Resolve the two NEEDS-SPLITTING ambiguities above (or make and log a default decision,
   per this project's autopilot rules) before moving anything.
2. Move SHARED first (lowest churn — nothing in SHARED should import from CORE/SCHOOL), run
   `flutter analyze`, fix.
3. Move CORE feature dirs one at a time, `flutter analyze` after each (per FULL_BUILD_LIST's
   own instruction: "incrementally per feature area, not all at once").
4. Move SCHOOL feature dirs one at a time, same pattern.
5. Re-run the dark-mode `static const` palette fix (clubs_page.dart, courses_page.dart) either
   just before or just after their move — don't do the color restructuring twice.
