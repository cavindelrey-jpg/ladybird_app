# Performance backlog

Same format as polish/TASKS.md — one unchecked item per commit, gated by
`flutter analyze`. Run with:
  .\polish-loop.ps1 -TasksFile polish/TASKS_PERF.md

Each item below maps a generic performance principle onto a REAL,
verified finding in this specific codebase — not a generic checklist.
Where something was checked and found NOT to be a problem, it's marked
done with a note, not silently omitted.

## N+1 queries (Firestore equivalent: individual .get() in a loop instead of batching)
- [x] `MagazineRepository.watchBookmarkedArticles`,
      `PublicCourseRepository.watchBookmarkedCourses`, and
      `AcademicContentRepository.watchSavedContent` all had exactly
      this: one query for bookmark/save IDs, then a for-loop calling
      `.get()` once per document (up to 30 individual reads). Fixed —
      grepped for the exact pattern across every repository and found
      a third instance beyond the two originally suspected; all three
      now use a single batched `.where(FieldPath.documentId, whereIn:
      ids)` query (chunked at 30) instead of N sequential .get() calls.
- [x] Checked `academic_content_repository.dart` and
      `attendance_repository.dart`'s similar-looking for-loops (lines
      186, 43) — these iterate over an already-fetched `snap.docs` or
      `records` list to build in-memory results, not to issue new
      per-item network calls. Not the N+1 pattern, no fix needed.

## Missing indexes
- [x] Already tracked as its own ongoing item — see CLAUDE.md's "known
      gotchas" and `firestore.indexes.json`. Not duplicating here;
      cross-reference that file when adding any new `.where()` +
      `.orderBy()` combination on a different field.

## Over-fetching (Firestore equivalent: no field selection, but more
## relevantly here: no .limit() on collection reads)
- [ ] Add `.limit()` with a sensible cap to `follow_repository.dart`'s
      unbounded stream queries.
- [ ] Add `.limit()` to `hero_slide_repository.dart`'s watchActive() —
      this one's genuinely small (a handful of banners) but should
      still have an explicit cap rather than relying on "there happen
      to only be a few documents."
- [ ] Add `.limit()` to `timetable_repository.dart`'s unbounded queries.
- [ ] Add `.limit()` to `accounts_repository.dart`'s unbounded queries —
      check this one carefully, since admin account-list screens may
      legitimately need every account; if so, don't cap it, instead add
      a code comment explaining why it's intentionally unbounded, and
      check it off with that note instead of adding a limit.
- [ ] Add `.limit()` to `course_repository.dart`'s (school-scoped
      courses) unbounded queries.
- [ ] Add `.limit()` to `attendance_repository.dart`'s unbounded
      queries where they represent a growing list over time (e.g. all
      historical attendance records for a course) rather than a fixed
      small set.

## No pagination (beyond just capping the initial fetch)
- [ ] Confirmed earlier in this project's history: no existing
      cursor-based "load more" pattern exists anywhere in the app. Once
      the `.limit()` items above are done, evaluate whether Magazine
      feed, Courses marketplace, and Library actually need real
      cursor-based pagination (startAfterDocument) given real expected
      data volume, versus whether a higher static `.limit()` is
      sufficient for now. Don't build a new pagination abstraction
      speculatively — only if a specific feed's realistic item count
      would actually exceed a single reasonable page.

## Blocking the main thread
- [x] Checked: `compute()` is already correctly used for both real
      heavy-parsing spots (docx import in the Course composer, and the
      in-app docx viewer in Library) — confirmed via grep, not
      assumed. No other CPU-heavy synchronous work (large JSON
      decoding, image processing, etc.) found elsewhere in the
      codebase as of this check.
- [ ] Re-check this item if any new file-parsing feature is added later
      — heavy parsing belongs in `compute()`, not inline in a widget's
      build/state method.
