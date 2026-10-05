-- ============================================================================
-- Maps the remaining real courses.level values (Anglophone Cameroon grade
-- names) onto the 5 canonical course_levels names, per explicit curriculum
-- guidance from the user (not guessed): Form 1-2 = Junior Secondary,
-- Form 3-4 = Senior Secondary, GCE Advanced Level / Advanced Level = High
-- School (A-Level is taken in Lower/Upper Sixth, still secondary school).
-- Completes the fix started in 20260902180000 for the remaining courses
-- that were invisible in the new Courses IA due to a level-name mismatch.
-- ============================================================================

update public.courses set level = 'Junior Secondary' where level in ('Form 1', 'Form 2');
update public.courses set level = 'Senior Secondary' where level in ('Form 3', 'Form 4');
update public.courses set level = 'High School' where level in ('GCE Advanced Level', 'Advanced Level');
