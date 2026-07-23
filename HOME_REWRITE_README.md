# Home page rewrite — Gamma's UI, real data underneath

## Files in this drop

**New:**
```
lib/models/hero_slide.dart
lib/models/magazine_article.dart          (Top Writers support)
lib/models/daily_challenge.dart
lib/repositories/hero_slide_repository.dart
lib/repositories/magazine_repository.dart
lib/repositories/daily_challenge_repository.dart
lib/pages/daily_challenge_page.dart       (real MCQ flow, real XP)
lib/features/library/library_reader_page.dart  (page-position tracker — see note below)
```

**Modified:**
```
lib/models/app_user.dart          + bio/educationLevel (earlier drop, re-applied)
                                   + xpTotal, streakDays, lastActiveDate,
                                     weekActivityDates, continueReading* fields
lib/models/library_item.dart      + totalPages (optional)
lib/models/models.dart            + new exports
lib/repositories/library_repository.dart
                                   + countAll() real aggregate count
                                   + recent() for Recommended
lib/repositories/repositories.dart + new exports
lib/services/auth_service.dart    + signInWithGoogle(), recordDailyActivity(),
                                     addXp(), setContinueReading()
lib/features/dashboard/universal_home_page.dart  — full rewrite
```

## What matches the mockup

Layout, card shapes, colors, and structure are Gamma's — greeting/avatar
block, 3 stat pills + week dots, single big-image Library banner with
gradient + CTA + dot indicator, 5-icon Quick Access row, Today's
Progress + Daily Challenge side by side, Top Writers + Recent
Announcements side by side, Recommended for You row.

Two tweaks applied per your notes:
- **Tighter avatar↔stat-pill gap** — avatar column is now a fixed 128px
  width instead of an `Expanded(flex: 2)`, so the stat pills sit right
  next to the name block instead of floating across a wide flex gap.
- **Stronger shadow ("glow")** — every card on this page uses a local
  `_glow` shadow (`alpha 0x14`, blur 20) instead of Gamma's near-invisible
  default (`alpha .02–.03`). This is scoped to this file only — I didn't
  touch your app-wide `Shad` tokens, so nothing else changed shade.

Quick Access is now your fixed 5 (Magazine, Clubs, Library, Past
Questions, Quizzes) with the "New" badge removed from Quizzes, per your
call — no more usage-based ranking on this row.

## What's real vs. what's an honest empty state

| Card | Source |
|---|---|
| Avatar / name / role | `AppUser` — real |
| Day Streak | `AppUser.streakDays`, recomputed on every Home load from `lastActiveDate` — real, resets if a day is missed |
| XP Points | `AppUser.xpTotal` — only ever incremented by `addXp()`, called from Daily Challenge (10 XP/correct answer) |
| Courses count | `AppUser.courseIds.length` — real, was already there |
| Week dots (M–S) | `AppUser.weekActivityDates` — real dates the app was opened, not a fixed pattern |
| Library banner | `HeroSlideRepository` — empty until you (superAdmin) add a slide; no fake "4,521 Resources" |
| Today's Progress / Continue Reading | Real, but minimal — see note below |
| Daily Challenge | `DailyChallengeRepository` — shows "No challenge today" until one is seeded for that date; one attempt per user per day, no replay farming |
| Top Writers | `MagazineRepository.topWriters()` — empty until an article exists |
| Recent Announcements | `AnnouncementRepository` — empty until a real one is posted |
| Recommended for You | Mix of `LibraryRepository.recent()` + `CourseRepository` (courses only for school-linked users; independent users get Library-only, gracefully) |

## Important scope note: Continue Reading / Today's Progress

`LibraryReaderPage` is **not** a real in-app PDF/document reader — building
one needs a PDF-viewer package and is a bigger feature on its own. What
ships here is a real, minimal page-position tracker: it opens the file via
its external download link and lets the person record which page they're
on with +/- buttons. That position is genuinely theirs (not fabricated),
which is what "Page 14 of 26" now means — but the actual in-app page
turning/rendering isn't built. Flag it if you want a true reader next.

## 3 manual steps
1. **pubspec.yaml** — paste `pubspec_additions.yaml`, `flutter pub get`.
   Register your Android SHA-1 for Google Sign-In (command included).
2. **Firestore rules** — merge `firestore_rules_additions.txt`.
3. **Seed a Daily Challenge** — until you (or a lecturer) write a doc to
   `dailyChallenges/{today's yyyy-MM-dd}` with `subject`, `title`,
   `questions` (array of `{prompt, options, correctIndex}`), and
   `xpPerCorrect`, the card will correctly show "No challenge today."
   Same for `heroSlides` — add one document and the banner appears.

## Still open
- Recommended card tap targets both currently route to Library/Courses
  landing pages, not a specific item detail (no per-article/course detail
  screens exist yet).
- Quick Access's Magazine/Clubs/Past Questions/Quizzes still open
  `ComingSoonPage` — only Library is a real screen.
