# Homepage navigation — verify before fixing

IMPORTANT CONTEXT, checked before this list was written: several of the
claims behind this list describe **intentional, correct behavior**, not
bugs. Specifically — a "Coming Soon" / "Sign in required" page shown to
a GUEST (not-logged-in) user tapping notifications or a Quick Access
icon is CORRECT, honest gating (a guest genuinely can't access
account-specific features) — do not remove or "fix" that gating. The
actual bug is narrower than the original report suggests. Confirmed
before this list was written:
  - Search button: genuinely broken (`showToast('Search is coming
    soon.')`, does nothing useful) — real bug, item 1 below.
  - "Top Writers is dead": FALSE, it's a real 117-line built page.
  - "Every Quick Access icon leads to Coming Soon": FALSE for signed-in
    users — only "Lecture Notes" is genuinely unbuilt; everything else
    already routes to a real page for a real account.
For every item below, verify the actual current behavior AS A SIGNED-IN
USER (not guest) before changing anything, and mark items done-with-a-
note if the described bug doesn't reproduce for a real account.

Run with: .\polish-loop.ps1 -TasksFile polish/TASKS_HOMEPAGE_NAV.md

## 1. Search — confirmed real bug
- [ ] Build a real search page/flow. Should search across content
      types that already have repositories (Magazine articles, Courses,
      Library/academic content, Clubs) using each repository's existing
      query methods — check whether any repository already has a
      `search`-style method (Messaging's `searchUsers` is one existing
      example of the pattern) before inventing a new search mechanism.
      Wire the Home page's search icon to it instead of the toast.

## 2. Notifications — verify signed-in behavior specifically
- [ ] Confirm: does a SIGNED-IN user tapping the notification bell see
      a real NotificationsPage with real data, or a Coming Soon page?
      (Expected: real page already exists — verify, don't assume either
      way.) Only fix if the signed-in path is actually broken. Guest
      behavior showing "Sign in required" is correct and should NOT be
      changed.

## 3. Profile/avatar images always open the profile
- [ ] Audit every place an avatar/profile image appears across the
      app (Home, Magazine authors/comments, Club members, Courses
      contributors, Messages) and confirm each is tappable and opens
      the correct profile. Several of these were fixed in earlier work
      on this project — verify each one rather than assuming all are
      broken or all are fixed. Fix only the ones that genuinely aren't
      wired.

## 4. Club banners
- [ ] Verify: do club banners/cards actually open the real club page
      (info, members, publications, messaging) for a signed-in user, or
      a placeholder? Fix only if genuinely broken for a real account.

## 5. Quick Access — only the confirmed real gap
- [ ] "Lecture Notes" Quick Access destination is genuinely unbuilt
      (confirmed — routes to ComingSoonPage for everyone, not just
      guests). Either build a real destination for it, or remove it
      from the Quick Access list if it's not actually a planned near-
      term feature — ask via a REPORT.md note if unsure which, don't
      guess. Do not change how any OTHER Quick Access item is gated.

## 6. Top Writers — verify only, likely already correct
- [ ] Confirm the Top Writers page (already exists, ~117 lines) shows
      real rankings/stats and that tapping a writer opens their real
      profile and publications. Mark done-with-a-note if this all
      already works; only fix genuine gaps found.

## 7. Recent Announcements — verify only
- [ ] Confirm tapping into Recent Announcements shows a real
      announcements list/detail view, not a Coming Soon page, for a
      signed-in user. Fix only if genuinely broken.

## Rules
- Verify against the REAL current file and REAL signed-in behavior
  before changing anything — this list's source material was written
  against claims that turned out to be significantly stale.
- Never remove or weaken guest-mode sign-in gating — that's correct
  product behavior, not a bug.
- Never stop and wait for input; skip + log to REPORT.md + continue.
- flutter analyze after each item, one commit per item.
