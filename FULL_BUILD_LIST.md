# ACADEMIA + GREEN HILL — FULL BUILD LIST (ONE-DAY AUTOPILOT RUN)

THIS FILE CONTAINS EVERYTHING. NOTHING FROM VIBE_FIX.MD, COMPILER-PROCESS.MD, OR THE PROMPT PACK HAS BEEN TRIMMED, DEFERRED, OR SCOPED DOWN. PASTE THE ENTIRE THING INTO CLAUDE CODE AS ONE MESSAGE.

---

## AUTOPILOT RULES — ABSOLUTE, NO EXCEPTIONS

- NEVER STOP. NEVER WAIT. NEVER ASK A QUESTION AND PAUSE FOR A REPLY.
- YOU HAVE FULL AUTHORITY TO ADD, EDIT, DELETE, OR RESTRUCTURE ANY FILE OR FOLDER IN THIS PROJECT. DO NOT ASK BEFORE DELETING OR OVERWRITING ANYTHING.
- IF SOMETHING IS AMBIGUOUS, DECIDE IT YOURSELF AND KEEP MOVING. LOG THE DECISION TO docs/AUTOPILOT_LOG.md AND CONTINUE — DO NOT PAUSE TO LET ANYONE REVIEW IT.
- COMMIT AFTER EVERY COMPLETED ITEM, AUTOMATICALLY, WITHOUT ASKING. THIS IS A CHECKPOINT, NOT A PERMISSION GATE — DO NOT TREAT A COMMIT AS A PLACE TO STOP.
- RUN flutter analyze AFTER ANY CHANGE TOUCHING MORE THAN ~10 FILES, THEN KEEP GOING BASED ON THE RESULT.
- WORK ON A BRANCH CALLED demo-prep, NEVER DIRECTLY ON main/master.
- IF ONE APPROACH FAILS, TRY ANOTHER. IF UNSURE WHICH OF SEVERAL FIXES IS RIGHT, PICK ONE, IMPLEMENT IT, NOTE WHY, MOVE ON.
- WORK THROUGH EVERY PART BELOW IN ORDER, START TO FINISH, WITHOUT STOPPING BETWEEN PARTS. WHEN YOU FINISH THE LAST ITEM, KEEP AUDITING THE APP FOR ANYTHING ELSE BROKEN AND FIX IT. DO NOT STOP UNTIL EVERYTHING BELOW IS DONE.

## WORKING DIRECTORY

Primary: `C:\Users\12406\academia_cameroon\academia_app`
Also reference `academia_compiler` and `academia_loop` in the parent `academia_cameroon` folder wherever relevant to PART 15 (automation pipeline) and PART 16 (architecture split) — read them, use what's useful, don't ask permission to look.

---

## PART 1 — CRITICAL BUGS

1. **App logo**: still shows old logo despite new logo in assets/icon. Fix icon-generation config, regenerate launcher icon/splash/all internal logo references, grep for and remove every remaining old-logo reference.
2. **Homepage Firestore errors**: fix "permission denied" on Recommended for You (check Firestore rules and query target). Fix "query requires an index" on Top Writers (create the index). Fix Daily Challenge — currently a dead button. Fix Today's Progress — currently a dead button. Verify every homepage button navigates somewhere real.
3. **Homepage search**: missing/broken search functionality, returns no results despite content existing. Fix query implementation, Firestore permissions, and indexing/query logic so it returns real results.
4. **Profile navigation**: tapping profile icon/name should open Profile/Account page — currently doesn't. Fix it.
5. **Home banners**: cache banners, make them auto-slideshow every ~30 seconds, allow manual swipe, swiping must NOT reload the entire homepage or lose homepage state — only the banner component should update. Optimize image loading/caching.

## PART 2 — COURSES

6. **Course automation**: implement automatic course creation using the course-generation methodology from COMPILER-PROCESS.md — build the actual automated pipeline for turning structured academic material into courses, following the established textbook-like sequential structure. This is real implementation work, not a plan document.
7. **Browse My Curriculum**: investigate and fix slow loading — check database query, navigation, loading state, Firestore index, and excessive data retrieval. Add loading indicators. Make courses appear quickly.
8. **Courses banner**: replace the current unsuitable image. Let the admin change/select the banner. Do not hard-code it — store the selection remotely.

## PART 3 — LIBRARY

9. **Library categories vs tags**: remove the dynamic-tag approach (currently every upload creates a new tag). Build a fixed Library category system like the Courses structure. Define the permanent categories, make them usable for filtering/navigation, require admins to select from existing categories on upload rather than creating new ones.
10. **Library Firestore errors**: identify every Library query requiring an index, create all necessary composite indexes, verify permissions. Test loading, category filtering, resource retrieval, search, recommendations, and offline resources.
11. **Save Offline vs Continue Learning**: define exactly what each means, ensure both use the correct data source/state, make saved resources persist correctly.
12. **Library banner**: replace, make admin-configurable, store remotely rather than hard-coded.

## PART 4 — PAST QUESTIONS

13. Apply the same structural fixes as Library: fix Firestore/index problems, establish fixed categories, fix resource loading, review search/filter, replace the banner and make it admin-configurable.

## PART 5 — CLUBS

14. **Discover Clubs**: fix the See All / View All button (currently does nothing) — navigate to the full clubs listing, or show a proper empty state if there are no clubs.
15. **Club search**: fix the bug where the search bar disappears when typing (keyboard/input/state-management issue) — make it persistent while typing, and make search actually query the database.
16. **Club creation**: preserve current working functionality, add support for custom club banners, review the flow for completeness.

## PART 6 — CLUB MEMBERS & ADMINISTRATION

17. Build a proper membership/administration system to replace the current basic one: club owner/admin roles, support for multiple administrators, different member permission tiers, promote/demote administrators, remove members, invite members, a member list with profiles, moderation functionality, and club settings. Use established patterns from major community/messaging platforms as the reference standard rather than a minimal system.

## PART 7 — CLUB CHAT / MESSAGING (full-featured, not a basic text box)

18. Build the functionality users expect from WhatsApp/Telegram-tier messaging inside clubs:
    - **Messaging**: 1:1 messaging where applicable, group messaging, reply to messages, forward messages, edit messages, delete messages, message reactions, read/delivery indicators, typing indicators, online/offline status, timestamps, message search, pin important messages, mute conversations, notifications, unread message counts.
    - **Attachments** (currently unsupported): photos, videos, documents/files, voice messages, camera capture, image previews, file previews, upload/download handling.
    - **Club-specific**: admin announcements, admin moderation, member permissions, pinned messages, club rules/info, member management.
    - Research the feature sets of leading messaging apps to inform the spec, then implement — don't build an artificially limited version.

## PART 8 — GENERAL MESSAGING SECTION

19. Full audit of the existing Messaging page against modern messaging standards. Add missing core functionality, calling functionality where appropriate, attachments, media sharing, notifications, message states, search, conversation management, contact/user profiles, and blocking/reporting/muting. Use WhatsApp/Telegram as the functional benchmark, adapted to Academia.

## PART 9 — QUIZZES & TESTS

20. **Quizzes**: quizzes currently appear empty — determine why, build the quiz database structure, create automated quiz generation connected to Courses and Library/content, generate questions/answer options/correct answers/explanations from course material, assign difficulty levels, organize by subject/topic/course, store in Firestore.
21. **Tests**: fully design the test system — creation methodology, automatic question generation, grading, result storage, student progress tracking, connected to Courses/Curriculum.
22. **Grading Queue**: review current functionality, define what submissions enter the queue, define automatic vs manual grading, ensure teachers/admins can process submissions and grades save correctly.

## PART 10 — PROFILE & SETTINGS

23. **Profile**: fix navigation (also covered in Part 1), then audit the entire page — account information, profile editing, avatar/profile image, academic information, progress/statistics.
24. **Settings**: audit the full page, keep standard expected settings, add missing configuration options, verify account/privacy settings and notification settings.

## PART 11 — DARK MODE

25. Implement a real dark theme (current one is not actually dark). Audit every screen for dark-mode compatibility, replace hard-coded light backgrounds, ensure cards/text/icons/borders adapt correctly and banners/images remain visually appropriate. Add theme selection in Settings supporting Light / Dark / System-default, and persist the user's preference.

## PART 12 — SYSTEM-WIDE DATABASE AUDIT

26. **Firestore index audit**: audit every query in the app, identify all missing indexes, create required composite indexes, check query performance, remove unnecessary queries, ensure queries match security rules.
27. **Firestore permissions audit**: audit security rules; verify authenticated vs guest access, user-specific data access, public content access, organization/school data access, and access for Library, Clubs, Courses, and Recommendations specifically. Test every permission-sensitive feature.

## PART 13 — LOADING & PERFORMANCE

28. Audit Homepage, Browse My Curriculum, Library, Clubs, Search, Recommended content, Profile, Courses, and Past Questions. For each: add proper loading/error/empty states, avoid unnecessary full-page reloads, cache reusable data, minimize Firestore reads, optimize image loading, prevent duplicate queries.

## PART 14 — BANNER / ADMIN CONTENT MANAGEMENT

29. Build a central admin-controlled banner system replacing every hard-coded banner: admin can upload/change images and select which banner appears on which page (Homepage, Courses, Library, Past Questions, Clubs/promotional). Store configuration remotely, cache banners client-side, allow future replacement without app updates.

## PART 15 — AUTOMATION PIPELINE

30. Build the actual automated content-creation pipeline (not a design doc — working code):
    - **Courses**: input curriculum/topic → generate course structure → generate lessons → generate explanations → generate illustrations/images where appropriate → generate examples → generate summaries → store course.
    - **Quizzes**: generate from courses → generate MCQs → generate answers → generate explanations → assign difficulty → store quiz.
    - **Tests**: generate complete tests from curriculum/course content → configurable number of questions, difficulty, marks → generate answer keys.
    - Check `academia_compiler` for any existing methodology/code to reuse before building from scratch.

## PART 16 — PLATFORM ARCHITECTURE SPLIT

31. Perform the actual Academia-Core / School-Template / Shared-Infrastructure split described in COMPILER-PROCESS.md:
    - Read every file in `lib/`, classify into CORE (Library, Courses, AI Tutor, Tests/Quizzes, Magazine, Clubs, Messaging, Profiles, Search — useful even without a school), SCHOOL (Attendance, Timetable, Assignments, Marks, Calendar, Announcements, Dashboard, Institution/Admin management), SHARED (models, repositories, services, utilities, theme, auth, routing, Firebase, shared widgets), or NEEDS SPLITTING (mixed files — split them).
    - Physically move files into `lib/core/`, `lib/shared/`, `lib/school/`, updating imports as you go. Run `flutter analyze` incrementally per feature area, not all at once.
    - Produce the extraction checklist and final architecture summary to `docs/ARCHITECTURE_REPORT.md`.

## PART 17 — GREEN HILL BRANDING (WHITE-LABEL)

32. Add a compile-time branding/flag system: `lib/config/app_config.dart` (`AppConfig.mode` from `APP_MODE` dart-define: `platform` or `school`), `lib/config/branding.dart` (Branding class: appName, colors, logo/splash paths, loaded from `assets/branding/<BRAND_ID>.json`). Create `academia.json` and `green_hill.json` yourself with reasonable placeholder values for Green Hill Academy Complex — don't wait for anyone to supply real ones. Wire branding into theme/app bar/splash. Gate school-only nav behind `AppConfig.mode == 'school'`. Give the Green Hill build a distinct `applicationId`/package id. Build and verify both flavors.

## PART 18 — WEBSITE

33. Convert the Flutter app into a responsive desktop web app using Next.js + React + Tailwind + TypeScript. Keep the same logo, colors, typography, iconography, and premium feel — do not just stretch the mobile layout, redesign every page for desktop (sidebar navigation, larger cards, responsive grids, wider tables, dashboards, modern desktop UX). Production-quality, reusable components, accessible.
34. Build the public Academia marketing homepage: Hero (Academia powers digital schools), Platform Overview (Library/Courses/Magazine/AI Tutor/School Apps), Features (Attendance/Timetable/Fees/Clubs/Communication/Reports/AI), For Schools, For Students, For Teachers, For Administrators, Pricing, Contact, Footer. Modern, minimal, premium, educational, tech-inspired — comparable to Google Workspace/Shopify/Notion, not a local-school site.

## PART 19 — FINAL AUDIT

35. Test as guest, as a normal student, as a teacher, and as an administrator. Test on slow internet and offline. Test every: Firestore permission, navigation path, button, search function, banner, dark mode toggle, notification, messaging feature, club feature, course, library resource, past question, quiz, grading flow, and profile/settings screen. Write results to `docs/FINAL_AUDIT.md`.

---

## DEFINITION OF DONE

NO DEAD BUTTONS. NO UNEXPLAINED LOADING SCREENS. NO FIRESTORE INDEX ERRORS. NO FIRESTORE PERMISSION ERRORS. NO BROKEN NAVIGATION. NO MISSING SEARCH FUNCTIONALITY. NO HARD-CODED BANNERS WHERE ADMIN CONTROL IS REQUIRED. NO UNNECESSARY HOMEPAGE RELOADS. NO EMPTY CORE MODULES. NO INCONSISTENT LIGHT/DARK UI.

## EXECUTION INSTRUCTION FOR CLAUDE CODE

GO THROUGH PART 1 TO PART 19 IN ORDER. COMMIT AFTER EACH NUMBERED ITEM. LOG EVERY ASSUMPTION TO docs/AUTOPILOT_LOG.md. DO NOT STOP, DO NOT ASK, DO NOT WAIT FOR A RESPONSE AT ANY POINT. IF YOU FINISH EVERYTHING ABOVE, KEEP AUDITING THE APP FOR ANYTHING ELSE THAT LOOKS BROKEN OR UNFINISHED AND FIX IT. START NOW.
