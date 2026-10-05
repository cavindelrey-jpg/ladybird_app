-- ============================================================================
-- greenhills_app/ladybird_app's shared "education-level" top tier, reused
-- across every hierarchical content browser (Quizzes, Course Navigation,
-- Library). Small, real, admin-managed list — worth a real table rather
-- than a stub. Kept name-independent of "quiz" even though the old
-- Firestore collection was called quiz_categories, since nothing about
-- it is quiz-specific anymore (see models/academic_section.dart).
-- Same shared database as academia-cameroon; unused there.
-- ============================================================================

create table if not exists public.academic_sections (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  emoji       text not null default '',
  image_url   text not null default '',
  sort_order  double precision not null default 0,
  created_at  timestamptz not null default now()
);

alter table public.academic_sections enable row level security;

create policy "academic_sections_select_all" on public.academic_sections for select using (true);
create policy "academic_sections_write_lecturer" on public.academic_sections for all
  using (public.has_min_role('lecturer')) with check (public.has_min_role('lecturer'));
