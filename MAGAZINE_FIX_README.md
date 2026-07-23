# Magazine module compile-error fix

## Root cause
The Magazine pages you have (`magazine_feed_page.dart`, `article_composer_page.dart`,
`article_reader_page.dart`, `author_profile_page.dart`, `bookmarks_page.dart`,
`hero_slide_manager_page.dart`) call a much richer `MagazineArticle` /
`MagazineRepository` / `HeroSlideRepository` / `AuthService` API than the
minimal Top-Writers-only versions I shipped in the last two drops. I don't
have those page files myself — I reconstructed the exact required API
**purely from your analyzer error list**, matching every getter, setter,
named parameter, and method name it named.

**This means there's real risk of a mismatch on anything the errors didn't
surface** (e.g. exact param order in a constructor call, a type I guessed
wrong on `bodyDelta`). If `flutter analyze` still shows errors after this,
paste the new list (or the actual page files) and I'll tighten the fit —
this should be a fast second pass, not a redo.

## What's fixed

**`lib/models/magazine_article.dart`** (full rewrite)
- `MagazineArticle` now has: `description`, `bodyDelta` (untyped —
  works whether your composer assigns a `String` or a `List` from
  flutter_quill), `category`, `tags`, `schoolId`, `likeCount`,
  `featured`, `pendingAuthorXp` — all as mutable fields so
  `article.category = ...` etc. works directly.
- `ArticleComment` re-added (was accidentally dropped from the last
  drop's slimmed-down version — that's the `ArticleComment isn't a
  type` error).
- Added `kArticleCategories` / `kArticleTags` constants for the
  composer's pickers.

**`lib/repositories/magazine_repository.dart`** (full rewrite) — added:
`watchFeed`, `watchFeedFromAuthors`, `watchLocalFeed`, `watchFeaturedOnce`,
`watchByAuthor`, `watchComments`, `postComment`, `recordRead`,
`toggleLike`, `watchIsLiked`, `toggleBookmark`, `watchIsBookmarked`,
`watchBookmarkedArticles`, `publish`, `update`, `delete`,
`uploadThumbnail`, `settlePendingXp`, plus the existing `topWriters`.

`recordRead` + `settlePendingXp` implement the real 2-XP-per-unique-reader
rule from your product notes: each article tracks unique readers in a
`reads` subcollection, accrues `pendingAuthorXp` on the article, and
`settlePendingXp(userId)` (called once per session in `app_router.dart`,
which already expects this) sweeps all of that user's authored articles
and credits the total to `AppUser.xpTotal` in one shot.

**`lib/repositories/hero_slide_repository.dart`** — added `watchAll()`,
`delete()`, `reorder()` for the Hero Slide Manager page.

**`lib/services/auth_service.dart`** — added `changePassword()` (re-auth
+ update) and `sendPasswordResetEmail()`.

**`lib/pages/daily_challenge_page.dart`** — was missing the
`core/result.dart` import, so `Success`/`Failure` were unresolved. Fixed.

**`lib/features/library/library_page.dart`** — re-included as-is. The
"Target of URI doesn't exist" error means this file isn't present at
`lib/features/library/library_page.dart` on your end right now (the
import path itself is correct for that project structure). If it's
actually sitting somewhere else in your tree, tell me the real path and
I'll fix the import in `universal_home_page.dart` instead of you moving
the file.

## Not touched
The `info:`-level lint suggestions (`prefer_const_constructors` in
`universal_home_page.dart`) are harmless style notes, not errors — left
as-is, won't block your build.

## One thing to do
Firestore composite indexes: `watchFeedFromAuthors`, `watchLocalFeed`,
`watchFeaturedOnce`, and `settlePendingXp`'s query each combine a
`where()` + `orderBy()` (or two `where()`s) on different fields. The
first time each runs, your debug console will print an error with a
direct "create index" link — click through each one once.
