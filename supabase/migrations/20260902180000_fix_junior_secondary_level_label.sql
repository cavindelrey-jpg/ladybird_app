-- ============================================================================
-- Fixes 113 real courses whose `level` was "Junior Secondary School" instead
-- of the canonical "Junior Secondary" name seeded into course_levels by
-- 20260902090000_courses_ia_redesign.sql. The new Courses IA browsing
-- screens (courses_home_page.dart's level cards, level_subjects_page.dart,
-- etc.) match courses to a level by exact string equality against
-- course_levels.name -- this mismatch made all 113 of these courses
-- invisible in the new hierarchy (found via a live data audit after a user
-- report that their courses had "disappeared").
--
-- Deliberately narrow (exact string match on the one confirmed-unambiguous
-- case) rather than a fuzzy/heuristic rewrite -- the other real level
-- values in this table (Form 1-4, GCE Advanced Level, Advanced Level)
-- need a human curriculum decision on which of the 5 canonical levels
-- they belong to before touching them; see the follow-up migration once
-- that's decided.
-- ============================================================================

update public.courses
set level = 'Junior Secondary'
where level = 'Junior Secondary School';
