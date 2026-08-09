# Day 2 — Make Green Hill a Visibly Distinct Product

A build-time flag is enough to demo two products convincingly. You do not need the full `lib/core`/`lib/shared`/`lib/school` directory split for a demo — that's real refactoring worth doing later, but it doesn't change what's on screen. If you're short on time, skip section 2 entirely and only do section 1.

```
cd C:\Users\12406\academia_cameroon\academia_app
git checkout -b demo-prep-day2
git add -A && git commit -m "checkpoint before branding split"
```

---

## 1. Build-time flag + branding config (do this — highest value for the demo)
```
[AUTOPILOT: if the exact set of school-only nav items isn't obvious,
grep the codebase for anything matching attendance/timetable/marks/
announcements/admin-panel patterns, gate all of them, and log which
ones you found — don't stop to confirm the list with me first.]

Add a compile-time flag system so this one codebase can build as either
Academia (platform) or Green Hill (school client), using Flutter's
--dart-define.

1. Create lib/config/app_config.dart exposing AppConfig.mode, read from
   String.fromEnvironment('APP_MODE', defaultValue: 'platform')
   ('platform' or 'school').
2. Create lib/config/branding.dart with a Branding class: appName,
   primaryColor, secondaryColor, logoAssetPath, splashAssetPath.
   Load it from assets/branding/<BRAND_ID>.json, selected via
   --dart-define=BRAND_ID=green_hill (default 'academia').
3. Create assets/branding/academia.json and assets/branding/green_hill.json
   with placeholder values — I will fill in real Green Hill colors/name
   afterward.
4. Wire Branding.appName/colors/logo into theme, app bar, and splash
   screen, replacing hard-coded values.
5. Update the main navigation/router so school-only routes and
   bottom-nav/drawer entries only appear when AppConfig.mode == 'school'.
6. Update pubspec.yaml / Android applicationId so a BRAND_ID=green_hill
   build produces a distinctly identifiable app package, without
   touching the default Academia build.
Report every hard-coded brand reference and every nav entry you gated
to docs/DAY2_CHANGES.md.
```

Drop your real Green Hill logo/colors into `assets/branding/green_hill/` and `assets/branding/green_hill.json` yourself (this is content, not a code decision — Claude Code shouldn't invent your client's brand colors), then build both:
```
flutter build apk --dart-define=BRAND_ID=academia --dart-define=APP_MODE=platform
flutter build apk --dart-define=BRAND_ID=green_hill --dart-define=APP_MODE=school
```

## 2. Physical file split (optional — only if Day 1+2.1 finish early)
```
Read every file in lib/ and classify into:
- CORE — Academia-only features (Library, Courses, AI Tutor, Quizzes,
  Magazine, Clubs, Messaging, Profiles, Search)
- SCHOOL — school-only features (Attendance, Timetable, Marks,
  Announcements, Admin Panel)
- SHARED — models, repositories, services, theme, auth, routing,
  Firebase config, shared widgets

Output the classification as a table to docs/ARCHITECTURE_TRIAGE.md.
Do NOT move any files yet — this is a read-only classification pass.
```
Only proceed to actually moving files if there's spare time after Day 3's checklist is green — this is not required for the presentation to land.

## 3. Verify
```
[AUTOPILOT: build both variants and inspect the output yourself for
name/logo/color correctness rather than asking me to confirm — you can
read the generated app name/package id from the build output and the
branding JSON you wrote in step 1.]

Build and launch both APP_MODE variants. Confirm: Green Hill build shows
correct name/logo/colors, not Academia defaults, and school-only nav
items are visible. Academia build shows no school nav items. Report
pass/fail to docs/DAY2_VERIFICATION.md.
```

```
git add -A && git commit -m "Day 2: branding flag + Green Hill build verified"
```
