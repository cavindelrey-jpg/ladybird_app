# Green Hills session — Academia-general vs. School-only changes

This catalogs every change made in this session's work, split into two
buckets:

- **Academia-general** — belongs to the shared platform. Useful in any
  Academia-branded app, not tied to school membership/voucher status.
- **School-only** — part of the new school-voucher/marks/timetable
  system built for Green Hills. This is what you'd port into "the
  general Academia app" if you want every school (not just Green Hills)
  to get this functionality there instead of only in a Green-Hills-forked
  copy.

Every file path is relative to the repo root. Known issues/gaps are
called out inline so nothing gets silently ported over unfinished.

---

## 1. Academia-general changes

These touch shared infrastructure used by every account, school-linked
or not.

### 1.1 Theme/branding bug fix (the actual reason colors stayed blue)
- `lib/theme/app_colors.dart` — `AppColors.of(context)` had a dead
  fallback: it checked the Theme's registered `ThemeExtension` first,
  which was *always* present (registered by `AppTheme.light`/`.dart`),
  so the brand-aware fallback never ran. Fixed to check
  `Branding.current.brandId` first.
- `lib/theme/app_theme.dart` — `AppTheme.light`/`.dark` now register
  `AppColors.greenHillLight`/`greenHillDark` as their `extensions:`
  list (was the old, still-blue `AppColors.light`/`.dark`). Dark mode's
  entire button/input/nav-bar/chip/FAB color set was rebuilt from the
  green palette instead of the blue one.
- **Port as-is.** This bug exists regardless of school features — any
  Academia-branded build hits the identical dead-fallback bug.

### 1.2 Literal "Academia"/brand text sweep
Files: `lib/pages/about_academia_page.dart`, `help_support_page.dart`,
`search_page.dart`, `settings_page.dart`, `lib/features/clubs/clubs_page.dart`,
`create_club_page.dart`, `lib/features/courses_marketplace/course_reader_page.dart`,
`lib/features/magazine/magazine_feed_page.dart`, `article_reader_page.dart`,
`lib/features/entitlements/sales_desk_page.dart`, `redeem_voucher_page.dart`,
`lib/features/messages/chat_conversation_page.dart`, `lib/models/entitlement.dart`,
`lib/models/app_notification.dart`, `lib/screens/app_router.dart`,
`lib/services/config_service.dart`, `lib/core/constants.dart`.
- Replaced hardcoded "Academia" strings (support email framing, share
  text, empty states, the About page) with `Branding.current`-driven
  text or brand-neutral wording.
- **Port selectively** — re-check which of these literal strings should
  say "Academia" (correct in the general app) vs. were changed to
  Green-Hills-specific wording. Most were de-branded to generic wording,
  which is safe either way.

### 1.3 Academia content renames
- `lib/widgets/app_drawer.dart`, `lib/features/academic_content/academic_content_page.dart`,
  `lib/features/courses_marketplace/courses_marketplace_page.dart`,
  `lib/features/testing/quiz_categories_page.dart`,
  `lib/features/dashboard/universal_home_page.dart`
- Library → **Academia Library**, Courses → **Academia Courses**,
  Quizzes → **Academia Quizzes**, Tests → **Academia Tests**, in the
  drawer, each page's own header, and Home's quick-access tiles.
  Bottom-nav tab labels deliberately left short (space-constrained).
- **Port as-is** — this is exactly the "make clear what's Academia vs.
  what's the school's own" distinction, and applies to any school app
  built on this platform, not just Green Hills.

### 1.4 Quiz content (real, not fabricated)
- `quiz-calculus-integration.json`, `quiz-programming-foundations.json`
  (repo root) — 15 questions across MCQ/Structured/Essay for the two
  courses actually published in `public_courses`. **Not yet run through
  `compile-quiz.js --write`** — these are source files, not live data.
- **Port as-is** if the general Academia app shares the same
  `public_courses`/`tests` collections (it should, since Academia
  Courses/Quizzes are explicitly shared platform content per this
  session's own architecture decision).

### 1.5 Global "+" content-creation menu
- `lib/widgets/create_content_sheet.dart` (new), `lib/screens/app_router.dart`
  (FAB on `HomeShell`), `lib/features/courses_marketplace/courses_marketplace_page.dart`
  and `lib/features/magazine/magazine_feed_page.dart` (removed permanent
  "Create Course"/"Write a Post" cards).
- **Port as-is.** Course/Article/Photo/Video/Quiz creation are all
  Academia-wide features; nothing here reads schoolId or school role.

### 1.6 Announcement photo upload (was completely non-functional)
- `lib/models/announcement.dart`, `lib/repositories/announcement_repository.dart`,
  `lib/widgets/widgets.dart` (`AnnCard`), `lib/features/announcements/compose_announcement_page.dart`,
  `lib/features/announcements/announcements_page.dart`, `storage.rules`
  (`announcement_images/{id}.jpg`).
- The old "Image URL" field's value was never even read by `_publish()`.
  Replaced with a real device-photo pick → Storage upload → preview →
  publish flow.
- **Port as-is** — `Announcement.schoolId` is already optional/nullable
  in the model (announcements exist with or without a school scope), so
  this fix benefits the unscoped/general announcement feed too.

### 1.7 Message bubble contrast
- `lib/features/messages/chat_conversation_page.dart` — sent bubbles
  were a pale tint nearly indistinguishable from received bubbles,
  especially in dark mode. Sent is now solid `ac.primary` with white
  text/timestamp/read-receipt; received stays a neutral bordered surface.
- **Port as-is.** Messaging is a general Academia feature.

### 1.8 Quiz question images
- `lib/models/test.dart` (`TestQuestion.imageUrl` + serialization),
  `lib/repositories/test_repository.dart` (`uploadQuestionImage`,
  keyed `test_question_images/{testId}_{questionId}.jpg`),
  `lib/features/testing/test_composer_page.dart` (per-question image
  picker, any type — not MCQ-only), `lib/features/testing/test_taking_page.dart`
  (renders the image above the answer input when present), `storage.rules`
  (`test_question_images/{fileName}`, same role gate as the existing
  test-thumbnail rule).
- **Port as-is.** Same pick-then-upload-after-id-exists pattern already
  used for the test's own thumbnail; not school-specific.

---

## 2. School-only changes (Green Hills' voucher/school system)

This is the part to port into "the general Academia app" if you want
**every** school (not just a Green-Hills-branded fork) to get school
membership, role-based marks, timetable, etc. The whole point of its
design was genericity — see 2.1.

### 2.1 Core voucher/access architecture
- `lib/models/school.dart` (new) — `School` registry
  (`schools/{schoolId}`: `code`, `name`). **Generic — not hardcoded to
  Green Hills.**
- `lib/models/school_voucher.dart` (new) — `SchoolRole` enum
  (student/parent/teacher/classMaster/admin) and `SchoolVoucher` model.
  Code shape is `[SCHOOL_CODE][ROLE_CODE][RANDOM8]`, e.g. `GHS-4K9QX7M2`
  — the school code is data-driven from the `School` doc, not a literal
  string anywhere in code.
- `lib/models/teaching_assignment.dart` (new) — `(subject, classLevel)`
  pair, the real permission unit for marks entry.
- `lib/repositories/school_repository.dart`, `school_access_repository.dart`
  (new) — register a school, issue vouchers, redeem a voucher (atomic
  transaction, mirrors `EntitlementRepository.redeemVoucher`'s proven
  shape).
- `lib/features/onboarding/school_access_page.dart` (redemption UI),
  `school_admin_page.dart` (staff issuance UI, reachable from Settings).
- `lib/models/app_user.dart` — added `schoolRole`, `teachingAssignments`,
  `classMasterOfClass`, `schoolVoucherRef` fields; `isSchoolMember`,
  `isSchoolClassMaster`, `canRecordMarksFor()`, `canRecordAnyMarks`
  getters.
- `firestore.rules` — `schools/{schoolId}`, `school_vouchers/{code}`
  collections; `isValidSchoolVoucherRedemption()` carve-out on
  `users/{uid}`'s update rule (lets a user self-write schoolId/schoolRole
  ONLY as part of a verified, unused-voucher-referencing write).
- **Known gap**: nobody has actually run this end-to-end (no emulator/
  live Firebase in the sandbox this was built in). Test the full
  redeem flow — code entry → transaction → role upgrade → Profile
  gate flipping — before trusting it in production.

### 2.2 Fixed: any Academia account could see School Navigation
- `lib/pages/profile_page.dart` — School Navigation (School
  Connect/Marks/Timetable) was gated on `!user.isGuest` (any signed-in
  account). Now gated on `user.isSchoolMember` (a real redeemed
  voucher). **This bug exists in the general Academia app too if it
  shares this file** — check before assuming it's fine there.

### 2.3 Marks permission enforcement
- `firestore.rules` — `marks/{id}` rewritten from
  `canUploadContent() || canManageSchool()` (any lecturer, any school,
  any subject) to `canRecordMarksFor(schoolId, subject, classLevel)` —
  real teaching-assignment/class-master/admin scoping, plus school
  isolation on READ (previously any lecturer anywhere could read any
  student's marks cross-school — a real data leak, not hypothetical).
- `lib/features/school/marks_entry_page.dart` — subject picker now
  shows only what the signed-in staff member is actually assigned for
  the selected student's class, not the full subject catalogue.
- `lib/models/school_mark.dart` — added `academicYear` (was completely
  absent; marks from different years were indistinguishable before this).
- **Known gap**: same as 2.1 — never executed against a live project.

### 2.4 CSV marks import
- `lib/features/school/marks_csv_import_page.dart` (new) — downloadable
  template, per-row validation (including the same permission check as
  manual entry), student-name resolution scoped to the staff member's
  own school + class.
- **Known issue, already fixed this session**: originally written
  against `package:csv`'s `CsvToListConverter`/`ListToCsvConverter`,
  which a real `flutter analyze` run reported as "isn't a class" against
  the pinned `csv: 8.0.0` — never verified against real docs/network.
  Replaced with a small hand-written CSV encoder/decoder in the same
  file, no third-party dependency. **If you port this file, port the
  hand-written encoder/decoder too** — don't reintroduce the
  `package:csv` import.
- **Known gap**: student-name resolution requires an *exact* name match
  scoped to school+class; ambiguous/duplicate names fail closed rather
  than guess. Fine as a v1, but worth knowing before a real rollout with
  a large roster.

### 2.5 School page chrome cleanup
- `lib/features/school/widgets/school_shared_widgets.dart` —
  `schoolAppBar()` used to render a `BrandLogo` crest + subtitle on
  every Timetable/Marks/School Connect page. Removed both (redundant
  branding + marketing subheading item). Affects only these three pages.

---

## 3. Suggested porting order, if you go ahead

1. Section 1 (Academia-general) first — lower risk, no new data model,
   fixes a real theming bug that likely affects the general app too.
2. Section 2.1 (voucher architecture) — foundational, everything else
   in section 2 depends on `schoolRole`/`isSchoolMember` existing.
3. Section 2.2 → 2.3 → 2.4 → 2.5, in that order — each one assumes the
   previous is already in place.
4. Before trusting ANY of section 2 in production: actually redeem a
   test voucher against a real (non-production) Firebase project and
   confirm the Profile gate flips, marks permission denials behave as expected, and the CSV import round-trips a real file. None of that
   has been exercised outside of manual code review this session.

None of this was verified against a Dart/Flutter compiler in the
environment it was written in (no Flutter SDK available there) — treat
everything above as "written and reasoned through carefully, not yet
proven by a build."
