# Academia Website — Deferred Work

Not urgent for the demo. Notes for whoever picks this up next, so the
gap between "what exists" and "what the master directive actually asks
for" isn't lost.

## Current state (as of 2026-08-10)

`academia_website/` (chosen over the thinner, competing `academia_web/`
folder — see `docs/AUTOPILOT_LOG.md` for why) is a **marketing/
informational site only**:

- Hero, PlatformOverview, Features, Audiences, Pricing, Contact sections
- A Green Hills Academic Complex case-study section (real logo/colors)
  making the white-label story concrete
- Builds clean (`npm run build` — 0 errors, fixed 3 pre-existing
  ESLint errors nobody had caught before this)
- **Not deployed anywhere** — exists only on disk, no hosting configured
- **No git repo of its own** — same for `academia_compiler/` — neither
  is under version control right now

## What the master directive actually asks for

> Academia Website ↔ Academia Backend ↔ Academia Mobile App
>
> The website and app are two interfaces into the same product.

This site does not do that yet. It has no login, no connection to the
Firebase backend, no live Library/Courses/Magazine data, no student
dashboard. It's the "front door" (explain the platform, showcase Green
Hills, capture leads), not a second functional interface — closer to
youtube.com's marketing page than youtube.com's actual video experience.

## What real portal parity would need

1. **Auth** — Firebase Auth on the web (same project, same users) so a
   student/school account works identically on web and mobile.
2. **Live data** — Firestore/Storage reads for Library, Courses,
   Magazine, wired the same way the Flutter app's repositories already
   do it (same collections, same security rules — those are already
   correct and deployed, this is just a second client reading them).
3. **A real student/school dashboard** on the web — at minimum: browse
   Library, browse/read Courses, read Magazine, view a school's
   Announcements/Timetable if linked to one (mirrors `SchoolHomePage`'s
   Quick Access set on mobile).
4. **Deployment** — Firebase Hosting is the natural choice (same
   project, free tier comfortably covers this size of site — confirmed
   with the user 2026-08-10). `firebase deploy --only hosting` once a
   `firebase.json` hosting target is configured.
5. **Git** — put `academia_website/` under version control (currently
   has none) before doing more work on it, for the same reason
   `academia_app` already is.

## Not started

None of the above is built. This file exists so "the website is done"
isn't assumed later — it's done at the marketing-page level the user
explicitly asked for on 2026-08-10 ("website itself to be presentable
enough for the demo"), not at the full-portal level the original master
directive describes.
