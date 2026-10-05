-- ============================================================================
-- Two real, wired-up fields greenhills_app's fork added on top of the
-- shared courses/announcements tables:
--   courses.video_url        — an optional video lesson attached to a
--                               course (Gold-tier "Video Course" gate,
--                               see core/feature_access.dart there).
--   announcements.image_url  — composer-uploaded photo, replacing a
--                               free-text field the old composer never
--                               actually wired in.
-- Same shared multi-tenant tables as academia-cameroon; nullable and
-- unused there.
-- ============================================================================

alter table public.courses add column if not exists video_url text;
alter table public.announcements add column if not exists image_url text;
