-- ============================================================================
-- greenhills_app/ladybird_app additions on top of the shared tests/
-- test_attempts tables. Essay key points, structured expectedPoints, and
-- per-key-point grading outcomes all live inside the existing `questions`/
-- `responses` jsonb columns (schema-less, no migration needed) — only
-- these flat top-level fields need real columns:
--   tests.category/topic/thumbnail_url    — Category > Subject > Topic
--     browse hierarchy (mirrors PublicCourse's tree one tier shallower).
--   test_attempts.level_multiplier/attempt_multiplier — frozen at submit
--     time so a later profile change or retry-count never retroactively
--     alters an already-in-progress attempt's XP math.
-- Same shared tables as academia-cameroon; unused there.
-- ============================================================================

alter table public.tests
  add column if not exists category text not null default '',
  add column if not exists topic text not null default '',
  add column if not exists thumbnail_url text;

alter table public.test_attempts
  add column if not exists level_multiplier double precision not null default 1.0,
  add column if not exists attempt_multiplier double precision not null default 1.0;
