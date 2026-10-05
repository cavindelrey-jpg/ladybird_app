-- ============================================================================
-- greenhills_app's HeroSlide carries two real additions academia-cameroon's
-- original didn't need:
--   1. `messages` and `section` destinations (production_plan.md §7B —
--      "jump to a sub-section of the current page" navigation, plus a
--      Messages banner destination).
--   2. `placement` — which surface a slide belongs to. Only 'home' is
--      actually current (every other placement was retired in favor of
--      automatic recommendations), but existing rows stamped with a
--      retired placement string still need to read back as "orphaned"
--      rather than silently vanishing (see HeroSlideRepository
--      .watchOrphaned) -- hence a free-text column, not an enum, so a
--      retired value doesn't become an invalid row.
-- Same shared hero_slides table as academia-cameroon; harmless default
-- there ('home' has no meaning for that app, which never reads the column).
-- ============================================================================

alter type public.hero_destination add value if not exists 'messages';
alter type public.hero_destination add value if not exists 'section';

alter table public.hero_slides add column if not exists placement text not null default 'home';
