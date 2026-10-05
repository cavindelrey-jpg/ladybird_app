-- ============================================================================
-- greenhills_app/ladybird_app's per-category image for the Courses
-- marketplace grid (Mathematics, Science, ...) — small enough to be a
-- real table rather than a stub, keyed by the fixed category string
-- itself (kCourseCategories), not a uuid.
-- Same shared database as academia-cameroon; unused there.
-- ============================================================================

create table if not exists public.course_category_visuals (
  category   text primary key,
  image_url  text not null default ''
);

alter table public.course_category_visuals enable row level security;
create policy "course_category_visuals_select_all" on public.course_category_visuals for select using (true);
create policy "course_category_visuals_write_lecturer" on public.course_category_visuals for all
  using (public.has_min_role('lecturer')) with check (public.has_min_role('lecturer'));
