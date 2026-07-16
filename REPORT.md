# Loop 5 Report

All 7 items in TASKS_LOOP5.md were completed and committed. No live
device, design decision, or credential was needed for any of them —
the one genuine environment blocker (below) is a tooling wall, not a
missing-input skip.

## 1. Magazine banner spacing
Found already in progress from an earlier uncommitted session pass
(chip row → banner gap set to 20px). Checked the app-wide convention:
16px is the dominant section-gap value used everywhere else
(content_upload_page, content_edit_page, course_detail_page,
assignments_page, calendar_page, article_reader_page, etc. — dozens of
call sites), 20px appears in only a couple of spots. Changed to 16px
to match the actual standard instead of the invented value.
Commit `3191590`.

## 2 & 3. Contributor profile pages showing empty
Confirmed the lead: `course_creator_profile_page.dart` and
`author_profile_page.dart` both ran `.where(...).orderBy(createdAt)`
queries with no `snapshot.hasError` check, so a missing/undeployed
composite index would silently render as an empty state instead of a
real error. Found substantial work already uncommitted from an earlier
pass; verified it and added on top:
- Both StreamBuilders now check `hasError`, log via
  `CrashService.instance.recordError`, and show a real "couldn't load
  — <error>" message instead of the generic empty state.
- Verified `firestore.indexes.json` already declares the exact
  composite indexes both queries need (`public_courses:
  creatorId+createdAt`, `articles: authorId+createdAt`) with matching
  field order/direction. Nothing to deploy-and-flag here — the indexes
  are already in the file (whether they're deployed to the live
  Firestore project is a separate step requiring `firebase deploy
  --only firestore:indexes` with CLI auth only the human has — flagged
  below, not attempted).
- Added the missing stat fields: follower/following counts, bio, and
  institution name (fetched from the full user doc via a
  `_watch*User` stream, since the article/course-derived header only
  carried name/photo).
Commit `df8664a`.

## 4. Library subject navigation
Found already in progress: tapping a subject now sets `_subjectFilter`
and routes to `_LiveFeed`, which calls
`AcademicContentRepository.watch(subject: ...)` — a real filtered
query, not a generic list. Verified end-to-end (subject tap → state →
repository query → composite index in `firestore.indexes.json`, all
present and matching). Added on top:
- `hasError` handling on that feed's StreamBuilder (same
  FAILED_PRECONDITION risk as items 2/3).
- Empty-state copy that names the subject/type combination instead of
  a generic "no content" message.
- Pagination: the repository's `watch()` already caps at `limit(80)`.
  Checked for an existing cursor-based "load more" pattern elsewhere in
  the app to extend (per the task's explicit instruction not to invent
  a new one) — found none anywhere in the codebase. Building a full
  paginated-loading abstraction from scratch for this one screen would
  be new-pattern invention outside scope, so left the existing cap in
  place as adequate for a single school's per-subject volume.
Commit `7a9050c`.

## 5. Friends list without searching
`find_people_page.dart` was genuinely search-only before this: with an
empty query it showed nothing but a "Search for someone to connect
with" prompt, so existing friends were invisible unless you already
knew their name. Rebuilt the page (still reached via the existing
"Find People" entry point) to open into three live, real-data sections
by default:
- **My Friends** — new `MessagingRepository.watchFriendIds` /
  `.watchFriends` (mutual friendship docs → full `AppUser` profiles,
  chunked past Firestore's 30-item `whereIn` cap). Tapping opens the
  conversation directly.
- **Recent Conversations** — existing `watchConversations`, reused.
- **Suggested Friends** — new `MessagingRepository.suggestedFriends`:
  same-school users you're not already friends with and haven't
  already sent a pending request to. Deliberately schoolId-based only
  — there's no recommendation engine in this codebase, and users with
  no `schoolId` (independent layer) get no suggestions rather than a
  fabricated list. Includes a manual refresh button since this is a
  one-shot fetch, not a live stream.
Typing in the search box filters all three lists by name (client-side)
and, for genuinely new people, still falls through to the existing
global `searchUsers` backend search below.

**Skipped: Online Friends.** Grepped the codebase for any
presence/heartbeat/last-active system — there isn't one anywhere
(confirmed by `chat_conversation_page.dart`'s own comment making the
same call for its "Online" status dot). Per the task's explicit
instruction not to invent a fake online indicator, this section was
not built. This is the one item from the original 4-part list not
implemented, and it's a data-availability limit, not an oversight.
Commit `8e1c199`.

## 6. Audit other StreamBuilders for missing hasError
Delegated the mechanical grep-and-fix sweep to a subagent (same
CrashService+ErrorView pattern, verified every result by reading the
diffs myself afterward). Fixed:
- `assignments_page.dart` — lecturer and student assignment lists
- `club_members_page.dart` — pending join requests
- `universal_home_page.dart` — home banner carousel
- `messages_home_page.dart` — incoming friend requests
- `timetable_page.dart` — class/lecturer timetable view

Adapted (not a literal copy of the reference pattern) in
`clubs_page.dart`: two `watchMyRequestStatus` StreamBuilders back a
small embedded status badge inside a fixed-layout tile/card, where a
full `ErrorView` would break the row. These record the error via
CrashService and fall back to the existing "no badge" look instead.

Left alone (already check `hasError`, just don't log to CrashService —
outside the stated scope of "doesn't check hasError at all"):
`messages_home_page.dart`'s recent-conversations section,
`courses_marketplace_page.dart`'s contributor feed,
`magazine_feed_page.dart`'s main feed.

`firestore.indexes.json`: added 6 missing composite indexes verified
against the actual query shapes (attendance; assignments x2;
timetable x2; the `comments` collectionGroup query used by
`MagazineRepository.watchUserComments`). None of the pre-existing
entries were reordered or removed.
Commit `424b691`.

## 7. General UX polish
Audited rather than blanket-added, per "check first, don't duplicate":
- **Skeleton loaders**: already present broadly (`ShimmerCard`,
  `ShimmerCircle`, `ShimmerLine` used across academic_content,
  messages_home, and now the new Friends sections). A few screens
  (assignments_page, timetable_page) use a plain
  `CircularProgressIndicator` instead — judged as an existing, adequate
  loading state, not a "missing" one; left alone to avoid a broad
  low-value refactor.
- **Pull-to-refresh**: only one screen in the whole app uses
  `RefreshIndicator` (dashboard_page.dart). Everything else is backed
  by live Firestore streams that update themselves with no user action
  needed, which is why pull-to-refresh hasn't been built elsewhere —
  it would be mostly redundant. The one genuinely one-shot fetch
  introduced this session (Suggested Friends) isn't live, so it got a
  manual refresh icon instead of a full pull gesture (consistent with
  there being no existing pull-to-refresh pattern to extend).
- **Real empty-state messaging**: the shared `EmptyState` widget is
  already used broadly for full-page empty states; the new Friends
  sections use compact contextual text ("You haven't added any friends
  yet", "No conversations match '...'", etc.) matching the existing
  convention in `messages_home_page.dart`'s own recent-conversations
  section (plain `Text`, not the full-block `EmptyState`, for
  in-list/compact sections).
- **Preserved scroll position on back-navigation**: the main bottom-nav
  shell (`app_router.dart`) already uses `IndexedStack`, so tab
  switches preserve state/scroll for free. In-stack push/pop
  navigation preserves scroll via Flutter's default Navigator
  behavior; found no evidence of anything forcing list rebuilds on
  pop.
No code changes needed for this section beyond the refresh icon folded
into commit `8e1c199`.

## Skipped items requiring human input (none blocked mid-task)
- **Deploying the Firestore indexes** in `firestore.indexes.json` to
  the live project needs `firebase deploy --only firestore:indexes`,
  which needs Firebase CLI auth only the human has. Not attempted —
  the file itself is correct and complete; deployment is a separate
  step.
- **Online Friends** (item 5) — no presence system exists to back it;
  building one (heartbeat writes, presence collection, staleness
  rules) is a real feature addition, not a bug fix, and out of scope
  for this pass. Flagged as a genuine follow-up if wanted.

## Environment blocker: flutter analyze / flutter build could not run
`where flutter` / `where dart` resolve fine in this session
(`C:\flutter\bin\flutter.bat`, `C:\flutter\bin\dart.bat`) — this is
*not* the PATH-resolution gotcha CLAUDE.md already documented from a
prior loop. The actual blocker is different and new: invoking the
`flutter` binary at all — `flutter analyze`, `flutter --version`,
`flutter build apk --debug` — via either the Bash tool or the
PowerShell tool returns "This command requires approval" instantly,
every time, regardless of shell, invocation form (`.bat` vs plain,
quoted path vs unquoted), or subcommand. No settings.json/
settings.local.json exists in this repo's `.claude/` directory to
adjust an allowlist, and there's no human present in this unattended
session to grant the approval. This is a hard tool-permission wall,
not a retryable transient failure — confirmed after 4 independent
attempts across both shells including the most harmless possible
subcommand (`--version`).

Compensating verification used instead, for every file touched this
session:
- Re-read each full file after editing (not just the diff) to check
  brace/paren balance and control flow.
- Verified every new symbol referenced (`CrashService.instance
  .recordError`, `ErrorView`, `AppUser.fromFirestore`, `FieldPath
  .documentId`, `Institution.schoolName`, etc.) actually exists at the
  claimed signature by grepping its definition, not assuming from
  memory.
- Verified new/changed Firestore queries against `firestore.indexes
  .json` field-by-field (path, order, direction) rather than assuming
  a matching index existed.
- Re-derived one real bug this way before it was committed: an initial
  draft of `_SuggestedFriendsSection` used a nullable `filtered`
  variable and called `.map()` on it directly in the final `else`
  branch without re-asserting non-null (Dart doesn't promote across
  sibling `if/else` collection-if branches from an earlier `!`) — this
  was caught and fixed (`filtered!.map(...)`) purely by manual
  reasoning before commit, since there was no compiler available to
  catch it automatically.

This is a genuine tooling gap in this sandboxed session, not a code
issue. **A human should run `flutter analyze && flutter build apk
--debug` from a normal terminal** to get real compiler confirmation —
this loop could not obtain one after repeated attempts, per CLAUDE.md's
existing rule to log rather than silently skip verification.

## Files changed (by commit)
- `3191590` — `lib/features/magazine/magazine_feed_page.dart`
- `df8664a` — `lib/features/courses_marketplace/course_creator_profile_page.dart`,
  `lib/features/magazine/author_profile_page.dart`
- `7a9050c` — `lib/features/academic_content/academic_content_page.dart`
- `8e1c199` — `lib/features/messages/find_people_page.dart`,
  `lib/repositories/messaging_repository.dart`
- `424b691` — `lib/features/assignments/assignments_page.dart`,
  `lib/features/clubs/club_members_page.dart`,
  `lib/features/clubs/clubs_page.dart`,
  `lib/features/dashboard/universal_home_page.dart`,
  `lib/features/messages/messages_home_page.dart`,
  `lib/features/timetable/timetable_page.dart`,
  `firestore.indexes.json`
- `cc9a4fb` — `CLAUDE.md`
