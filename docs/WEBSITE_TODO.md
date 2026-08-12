# Academia Website — Status

Updated 2026-08-12. Most of what this file used to list as deferred is
now built — see below for what's real vs. still missing.

## Current state

`academia_website/` now has its own git repo (initialized 2026-08-12,
local only — no GitHub remote set up yet, that's a deliberate call left
to the user rather than guessing a repo name/visibility). Live at
https://academia-b1705.web.app (Firebase Hosting, same project as the
app).

**Marketing pages** (logged-out): Hero, Subjects, HowItWorks, Features,
Testimonials, Audiences, About (compact Green Hills partnership mention),
Pricing, Contact. Student-first framing — school-independent, per the
user's explicit direction (not a school-sales pitch).

**Real product surface** (logged-in), wired to the exact same Firebase
project/collections/security rules as the Flutter app:

- **Auth** — `/login`, `/signup`. Sign-up writes a `users/{uid}` doc that
  mirrors `AuthService.signUpIndependent()` field-for-field (same
  `accountType: independent`, `role: student`, etc.) — an account created
  on the website is indistinguishable from one created in the app.
- **Dashboard** (`/dashboard`) — post-login hub linking to the sections
  below.
- **Magazine** (`/magazine`, `/magazine?id=`) — live `articles` collection,
  renders `bodyDelta` (Quill Delta) via a custom `DeltaRenderer` matching
  the exact op shapes this codebase's own writers produce.
- **Courses** (`/courses`, `/courses?id=`) — live `public_courses`.
- **Library / GCE Past Papers** (`/library`, `/library?id=`) — live
  `academic_content`. Past papers gate behind the same unlock concept the
  app uses: `schoolAdmin`/`superAdmin`/`isPremium` accounts open directly,
  everyone else sees an honest "unlock in the app" message rather than a
  fake unlock button — full XP-purchase-flow parity wasn't built (see
  below).
- **Quizzes** (`/tests`, `/tests?id=`) — live `tests`, MCQ auto-grading,
  writes a real `testAttempts` doc matching `TestAttempt.toFirestore()`'s
  shape. Structured/long-form questions are collected but correctly left
  ungraded (`graded: false`), matching the app's real manual-grading
  model — not silently auto-scored.

Dynamic detail pages use a `?id=` query param, not a Next.js dynamic
route segment — required by static export (`output: "export"`), which
can't pre-render unknown Firestore IDs at build time.

**Firestore index added**: `tests` had no `published+createdAt` composite
index (only a `subject+published+createdAt` one, from the app's
subject-scoped picker) — the website's subject-agnostic "all quizzes"
list needed one. Added and deployed
(`academia_app/firestore.indexes.json`).

## Still missing / honestly out of scope for tonight

- **XP purchase/unlock flow for Past Papers** — admin/premium bypass
  works, but a non-premium student can't spend XP to unlock a paper from
  the website the way they can in the app (`XpRepository.isPaperUnlocked`
  / the unlock-sheet flow was not ported).
- **Clubs, Messaging, school-admin features (Attendance/Timetable/Marks)**
  — not built on the web at all. The user's explicit ask was Magazine +
  Courses + Quiz + Library/GCE Papers + sign-up; that's what's covered.
- **No GitHub remote** for `academia_website`'s new repo — exists only
  as a local git history right now.
- **Structured/long-form quiz grading queue** — the app has a real
  lecturer-facing grading queue for these; the website only collects the
  answer, there's no way to grade it from the web.
