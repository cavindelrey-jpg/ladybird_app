# Dashboard, Library, Courses & Offline

Run with: .\polish-loop.ps1 -TasksFile polish/TASKS_DASHBOARD_LIBRARY.md

## 1. Dashboard sidebar "Home" button — likely already fixed, verify first
No separate dashboard sidebar exists distinct from the main drawer
(`lib/widgets/app_drawer.dart`) — confirmed by file search. Earlier work
on this project already fixed the drawer's Home item to properly reset
the bottom-nav tab instead of leaving you on whatever tab you were on.
- [ ] Verify: as a signed-in user, open the drawer from a non-Home tab
      and tap "Home." Confirm it switches to Home correctly (not a
      blank/broken page). If it already works, mark this done with a
      note. Only investigate further (check for a truly separate
      "blank page" crash distinct from the tab-reset issue) if it
      genuinely still reproduces.

## 2. Library thumbnails not loading — real, investigate properly
- [ ] Investigate why document thumbnails fail to load. Check, in
      order: (a) is a thumbnail URL actually being generated/stored at
      upload time (`content_upload_page.dart`'s upload flow), (b) is
      the stored URL a valid, reachable Storage download URL, (c) does
      the widget displaying it handle a null/empty thumbnail with a
      real fallback icon rather than erroring silently, (d) are
      Storage security rules actually allowing read access to these
      files. Fix whichever of these is the actual root cause — don't
      guess, trace it.

## 3. Library tag system — this is a feature build, not a bug fix
Checked before this list was written: tags are entirely user-typed
free text (comma-separated input), not automatically/randomly
generated as originally reported — that specific claim doesn't match
the actual code. The REAL gap: there's no controlled/approved tag list.
- [ ] Build a controlled tag system: an approved tag list (subject-based
      categories likely already exist somewhere in the app — check
      before inventing a new taxonomy), a picker UI for users to select
      from existing tags instead of free-typing, and an admin-only path
      to add genuinely new tags to the approved list. Prevent exact-
      duplicate tags at write time.

## 4. Offline Library — real feature build
- [ ] Build a real offline-download system for Library content: local
      file caching (check `pubspec.yaml` for an existing package like
      `path_provider`, already a dependency, before adding a new one),
      a "downloaded" flag per content item, an Offline Library page
      listing what's actually been downloaded, storage usage display,
      and opening downloaded content without a network round-trip. This
      is genuinely substantial — if it needs to span multiple commits,
      split it into sub-checkboxes here rather than one giant diff.

## 5. Offline Courses — same treatment, separate feature
- [ ] Same as above but for Courses: download a course for offline
      access, list downloaded courses, open downloaded lesson content
      without network. Reuse whatever caching mechanism gets built for
      Offline Library rather than building a second, separate one.

## 6. Course creation review
- [ ] Review the course composer for placeholder/stub sections. Keep
      any real, intentional extension points (document them clearly if
      not already documented). Remove only genuinely dead/empty
      scaffolding that serves no purpose — do not remove real
      architecture on the assumption it's unused without checking.

## Rules
- Verify claims against real current behavior before fixing — several
  of the source claims for this list turned out to describe something
  different from what's actually in the code (see items 1 and 3 above).
- Never stop and wait for input; skip + log to REPORT.md + continue.
- flutter analyze after each item. One commit per item, or per
  sub-checkbox for the two Offline items given their size.
