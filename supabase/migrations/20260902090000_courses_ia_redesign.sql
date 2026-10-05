-- ============================================================================
-- Academia Courses information-architecture redesign: Education Level ->
-- Subject -> Topic -> Course -> Lesson (see polish/plan discussion — no
-- separate migration doc, this header is the record).
--
-- Reuses existing infrastructure rather than duplicating it:
--   - Subject  = courses.category (already free text, already close to the
--                target subject list — see kCourseCategories).
--   - Topic    = courses.topic (already the finest existing free-text tier).
--   - Level    = courses.level (already repurposed by greenhills_app's
--                course_navigation_page.dart to hold education-level names —
--                this migration just gives it a canonical, ordered source
--                table instead of ad hoc strings).
--   - Node icons/thumbnails = the existing curriculum_icons table (generic
--                key -> {emoji, image_url} lookup already built for this
--                purpose) — no new thumbnail table needed, just new key
--                formats (see PublicCourseRepository edu*IconKey).
-- The one genuinely new concept is course_lessons: a course was previously
-- a single piece of content; now it's a container for multiple lessons.
-- ============================================================================

-- Canonical, ordered list of the 5 education levels. A real table (not a
-- Dart constant) so the level cards on Courses Home, and the composer's
-- Level picker, are both driven by data an admin can edit without a code
-- change — see CLAUDE.md's "no fabricated/hardcoded data" rule.
create table if not exists public.course_levels (
  name        text primary key,
  sort_order  double precision not null default 0,
  created_at  timestamptz not null default now()
);

alter table public.course_levels enable row level security;
create policy "course_levels_select_authenticated" on public.course_levels for select
  using (auth.uid() is not null);
create policy "course_levels_write_lecturer" on public.course_levels for all
  using (public.has_min_role('lecturer')) with check (public.has_min_role('lecturer'));

insert into public.course_levels (name, sort_order) values
  ('Junior Secondary', 1),
  ('Senior Secondary', 2),
  ('High School', 3),
  ('Undergraduate', 4),
  ('Graduate', 5)
on conflict (name) do nothing;

-- A course is now a container for ordered lessons, each with its own
-- title/content — previously a course's body/body_delta WAS the content.
create table if not exists public.course_lessons (
  id                uuid primary key default gen_random_uuid(),
  course_id         uuid not null references public.courses (id) on delete cascade,
  title             text not null,
  video_url         text,
  body              text,
  body_delta        jsonb,
  duration_seconds  integer,
  view_count        integer not null default 0,
  sort_order        double precision not null default 0,
  cover_image_url   text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index if not exists course_lessons_course_id_idx on public.course_lessons (course_id);

alter table public.course_lessons enable row level security;
create policy "course_lessons_select_authenticated" on public.course_lessons for select
  using (auth.uid() is not null);
create policy "course_lessons_write_lecturer" on public.course_lessons for all
  using (public.has_min_role('lecturer')) with check (public.has_min_role('lecturer'));

-- Backfill: every existing course becomes its own first lesson, so nothing
-- written before this migration disappears from the new Lesson-list screen.
-- Includes video_url (added to `courses` by greenhills_app's
-- 20260829380000_courses_announcements_media_columns.sql, nullable/unused
-- in academia-cameroon) so an existing Gold-tier Video Course's video isn't
-- silently dropped by this migration.
insert into public.course_lessons (course_id, title, video_url, body, body_delta, sort_order, cover_image_url, created_at, updated_at)
select id, 'Lesson 1', video_url, body, body_delta, 100, cover_image_url, created_at, updated_at
from public.courses
where not exists (select 1 from public.course_lessons where course_id = courses.id);

-- Recent-course-views, mirroring content_recent_views exactly (see
-- 20260829180000_academic_content.sql) — powers Courses Home "Recent Reads".
create table if not exists public.course_recent_views (
  course_id   uuid not null references public.courses (id) on delete cascade,
  user_id     uuid not null references public.users (id) on delete cascade,
  viewed_at   timestamptz not null default now(),
  primary key (course_id, user_id)
);

alter table public.course_recent_views enable row level security;
create policy "course_recent_views_select_own" on public.course_recent_views for select using (user_id = auth.uid());
create policy "course_recent_views_upsert_self" on public.course_recent_views for insert with check (user_id = auth.uid());
create policy "course_recent_views_update_self" on public.course_recent_views for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- SECURITY DEFINER so any authenticated viewer can bump the counter without
-- needing lecturer-level write access to course_lessons — same rationale as
-- toggle_course_like etc. in course_engagement.sql.
create or replace function public.increment_lesson_view(p_lesson_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Must be signed in.'; end if;
  update public.course_lessons set view_count = view_count + 1 where id = p_lesson_id;
end;
$$;

alter publication supabase_realtime add table public.course_lessons;
alter publication supabase_realtime add table public.course_recent_views;
