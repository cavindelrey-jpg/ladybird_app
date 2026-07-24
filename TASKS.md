# Polish backlog

Checked items are done. The loop script claims the first unchecked item,
does exactly that one, verifies with `flutter analyze`, commits, and
checks it off. Add new items anywhere — order is priority, top to bottom.

Every item below was re-verified against the actual current codebase
tonight (not a stale scan) — line counts, file lists, and issue counts
are real, current numbers.

## Housekeeping (already done, listed for the record)
- [x] Remove the 6 confirmed-dead files (home_screen.dart, welcome_screen.dart,
      school_code_screen.dart, academia.dart, dashboard_page.dart,
      admin_accounts_page.dart) — done, zero references confirmed.
- [x] Background gradient system applied to all real content pages via
      shared `AppBackground` widget (44 pages) — done. Remaining
      "no AppBackground" files are legitimate exceptions: main.dart
      (no UI), app_router.dart (shell router), login_screen.dart
      (deliberately different pre-auth treatment), coming_soon_page.dart
      (shared placeholder widget, not a page).
- [x] Category-color duplication consolidated into `theme/category_colors.dart`.

## Hygiene / consistency
- [ ] Replace hardcoded `Color(0x...)` literals in
      `features/timetable/timetable_page.dart` with tokens from `theme/`.
- [ ] Replace hardcoded `Color(0x...)` literals in
      `features/institution/institution_header_widget.dart` with theme tokens.
- [ ] Replace hardcoded `Color(0x...)` literals in
      `widgets/premium_unlock_sheet.dart` with theme tokens.
- [ ] `theme/app_colors.dart` is a real, intentional dark-mode
      ThemeExtension, currently wired into Home only (see its own header
      comment for why `C.xxx` itself is deliberately untouched — const
      constructor risk). Extend the same AppColors.of(context) treatment
      to Library, Courses, and Magazine feed pages, matching Home's
      pattern exactly. Do not touch `C` itself.

## Large files (split for readability, no behavior change)
- [ ] `features/dashboard/universal_home_page.dart` (1250 lines) — extract
      distinct sections (greeting/stats row, banner carousel — already
      partly extracted as _HomeBannerCarousel, Quick Access grid, Daily
      Progress card, Top Writers/Announcements) into separate files
      under `features/dashboard/`.
- [ ] `features/academic_content/academic_content_page.dart` (797 lines)
      — same treatment.
- [ ] `widgets/widgets.dart` (733 lines) — split into per-widget files,
      keep `widgets.dart` as the barrel export so existing imports don't break.
- [ ] `features/magazine/magazine_feed_page.dart` (734 lines) — same treatment.

## Documentation
- [ ] Add `///` doc comments to public classes/methods in `core/` (small,
      high-value surface — do this folder first).
- [ ] Add `///` doc comments to public repository classes in
      `repositories/`.
- [ ] Add `///` doc comments to `models/` classes (fields + constructors).
- [ ] Sweep `features/**` for public widgets missing a one-line `///`
      description (lowest priority — do last, folder by folder).

## Correctness / lint
- [ ] Run `flutter analyze` and fix every reported warning/info (not just
      errors). File one commit per unrelated cluster of warnings, not one
      commit per warning.
- [ ] Run `dart format .` repo-wide as its own standalone commit before
      any other task starts, so later diffs aren't full of whitespace noise.
- [ ] There are 98 `catch (e) {` blocks in the codebase. Grep them and
      confirm each either logs via CrashService/returns a real Failure,
      or is genuinely intentional to swallow — route the ones that
      currently swallow silently through the existing error-handling
      path instead. Do this in batches by folder (repositories/ first,
      then features/), not all 98 in one commit.

## Architecture consistency
- [ ] Check whether every `features/<n>/` folder has a barrel file like
      its siblings (`features/<n>/<n>.dart`); add the missing ones.
- [ ] Confirm `pages/` items that duplicate `features/` functionality are
      either merged into the matching feature folder or documented as
      intentionally separate.

## Design-system follow-through (from tonight's UI audit — real, not fabricated gaps)
- [ ] Icon system consistency: audit whether every feature icon
      (Quick Access already does this correctly via QuickAccessRegistry)
      sits inside a soft colored circle with consistent size/padding
      everywhere it appears, not just Home.
- [ ] Spacing audit: check whether padding/margin values across the app
      actually stick to the 8-point grid (8/16/24/32/40/48) already used
      in most places, or whether arbitrary values have crept in — fix
      only genuine outliers, don't rewrite spacing that already matches.
- [ ] Empty-state audit: confirm every list/feed screen has a real
      illustration+explanation+action empty state (several already do —
      Bookmarks, Continue Reading, Recent Announcements) rather than a
      bare "no data" text, for the ones that don't yet.
