# TASKS_LOOP5.md — Zero-intervention loop scope

Work through these in order. Never stop for input — see Rules at the bottom.

## 1. Magazine banner spacing
The featured banner sits too close to the category chips ("For You" /
"Following" / etc.) right above it. Add proper vertical spacing between
the chip row and the banner carousel — consistent with spacing used
elsewhere in the app (check other screens for the standard gap value
rather than inventing a new one). This is separate from the earlier
top-of-screen padding fix — that one was SafeArea-to-header; this one
is chip-row-to-banner.

## 2 & 3. Course/Magazine contributor profile pages showing empty
STRONG LEAD, confirmed before this loop started — check this first
before doing anything else:
`course_creator_profile_page.dart` and `author_profile_page.dart` both
call `watchByCreator`/`watchByAuthor`, which both do
`.where(field, isEqualTo: x).orderBy('createdAt', descending: true)` —
a where+orderBy on different fields, which requires a Firestore
composite index. Neither page's StreamBuilder checks `snapshot.hasError`
at all, so if that index isn't deployed, the query fails silently and
the UI shows an empty state instead of the real error.
Do this:
- Add `if (snap.hasError) { ... }` handling to both StreamBuilders that
  surfaces the real error (log it via CrashService, show a real "couldn't
  load — [error]" state, not a generic empty state).
- Check whether `firestore.indexes.json` exists in the project root and
  already declares this composite index. If it exists but isn't
  deployed, note that in REPORT.md (deploying indexes needs
  `firebase deploy --only firestore:indexes`, which needs Firebase CLI
  auth — likely a human step, log it, don't attempt it blindly).
  If `firestore.indexes.json` doesn't exist or doesn't cover these two
  queries, add the needed index entries to it.
- While in these files: also add each profile's stat fields if genuinely
  missing (Courses/Articles Published count, Followers, Following, Bio,
  Institution) — check what's already there before adding, several of
  these may already exist.

## 4. Library subject navigation
Tapping a subject (Mathematics, Physics, etc.) in the Library should
immediately show that subject's resources (Books, Notes, Past Papers,
Videos, Assignments) — not require manual search. Check
`academic_content_page.dart` / `content_details_page.dart` and the
underlying repository query: confirm subject-tap actually passes the
subject as a filter into a real query, rather than just opening a
generic unfiltered list. Add pagination if a subject's resource count
could reasonably be large — check existing pagination patterns
elsewhere in the app first rather than inventing a new one.

## 5. Friends list should show existing friends without searching
Check `find_people_page.dart` and `MessagingRepository`/`FollowRepository`
for whatever "friends" already means in this data model (mutual follows?
accepted requests?). Add a real "Friends" view showing: My Friends,
Recent Conversations, Online Friends (only if presence/online-status
data already exists somewhere — do not invent a fake online indicator),
Suggested Friends. Search should filter this already-visible list, not
be the only way to see anyone.

## 6. Audit other empty-list pages for the same missing-error-handling pattern
Given the composite-index finding in items 2/3, grep the codebase for
other StreamBuilders on `.where(...).orderBy(...)` queries that also
don't check `hasError` — this exact bug pattern may exist elsewhere.
Fix each one found the same way: surface the real error instead of a
generic empty state.

## 7. General UX polish
Where genuinely missing (check first, don't duplicate): skeleton
loaders on list-loading screens, pull-to-refresh, real empty-state
messaging (not just blank), preserved scroll position on back-navigation.

## Rules — read before starting
- Never stop and wait for input. If something needs a live device, a
  design decision, or credentials only the human has (e.g. deploying
  Firestore indexes needs Firebase CLI auth) — skip it, write one line
  to REPORT.md, and move on immediately.
- IMPORTANT — a prior loop hit "flutter: command not found" inside this
  restricted shell even though it works fine in the human's own
  terminal. Before relying on `flutter`/`dart` commands, run `where
  flutter` (or check common paths) to resolve the full executable path,
  and use that full path for every flutter/dart command this session.
  If genuinely unresolvable, log it plainly in REPORT.md rather than
  silently skipping verification.
- Follow the existing repository pattern (Result<T>, Success/Failure)
  and existing UI conventions (C./Rad./AppText) exactly.
- Run `flutter analyze` after each numbered section and fix what it
  flags before moving on.
- Commit after each section completes and analyzes clean.
- When fully done, write a final REPORT.md: what got fixed, what got
  skipped and why (especially anything needing Firebase CLI auth or a
  live device), and the final `flutter analyze` output verbatim.
