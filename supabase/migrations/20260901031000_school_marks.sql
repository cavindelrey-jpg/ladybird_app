-- 20260901031000_school_marks.sql
-- Student marks/report cards. lib/repositories/school_marks_repository.dart
-- and the full staff entry UI (features/school/marks_entry_page.dart,
-- marks_csv_import_page.dart) already existed and worked end-to-end --
-- the repository was just a stub ("School marks aren't available yet." on
-- every write) because this table never existed. Mirrors
-- models/school_mark.dart exactly; `sequence` stores AcademicSequence's
-- enum name (e.g. 't1s1').
--
-- One mark per (student, subject, sequence, academic year) -- matches
-- SchoolMarksRepository.upsert()'s naming: re-entering the same
-- student/subject/sequence/year corrects the existing row rather than
-- duplicating it.

create table if not exists public.school_marks (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.institutions(id) on delete cascade,
  student_id uuid not null references auth.users(id) on delete cascade,
  class_level text not null,
  subject text not null,
  teacher_name text not null default '',
  sequence text not null,
  academic_year text not null,
  score double precision not null,
  max_score double precision not null default 20,
  graded_at timestamptz,
  graded_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  unique (student_id, subject, sequence, academic_year)
);

create index if not exists school_marks_student_idx on public.school_marks (student_id);
create index if not exists school_marks_school_class_idx on public.school_marks (school_id, class_level);

alter table public.school_marks enable row level security;

-- A student reads only their own marks. School staff (teacher/class
-- master/school admin -- AppUser.canRecordAnyMarks' own role list) can
-- read every student's marks in their own school. Fine-grained "only
-- YOUR subject/class" scoping (AppUser.canRecordMarksFor) stays a
-- client-side check, same trust boundary teachers already operate under
-- for a single school's own staff -- not a cross-tenant leak, and
-- consistent with how this app already treats staff-of-one-school as a
-- single trust domain elsewhere (e.g. club moderation).
create policy "school marks select" on public.school_marks
  for select
  using (
    student_id = auth.uid()
    or school_id in (
      select school_id from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
  );

create policy "school marks insert" on public.school_marks
  for insert
  with check (
    school_id in (
      select school_id from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
  );

create policy "school marks update" on public.school_marks
  for update
  using (
    school_id in (
      select school_id from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
  )
  with check (
    school_id in (
      select school_id from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
  );

create policy "school marks delete" on public.school_marks
  for delete
  using (
    school_id in (
      select school_id from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
  );

alter publication supabase_realtime add table public.school_marks;
