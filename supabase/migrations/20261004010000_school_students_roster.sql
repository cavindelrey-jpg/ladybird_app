-- 20261004010000_school_students_roster.sql
-- School student roster and class lists for bulk CSV import/export and class management.

create table if not exists public.school_students (
  id text primary key,
  school_id uuid not null references public.institutions(id) on delete cascade,
  student_name text not null,
  class_level text not null,
  matricule text,
  parent_contact text,
  gender text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists school_students_school_class_idx on public.school_students (school_id, class_level);
create index if not exists school_students_matricule_idx on public.school_students (school_id, matricule);

alter table public.school_students enable row level security;

create policy "school staff select students" on public.school_students
  for select
  using (
    school_id in (
      select school_id from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (
      select 1 from public.users where id = auth.uid() and role = 'super_admin'
    )
  );

create policy "school staff insert students" on public.school_students
  for insert
  with check (
    school_id in (
      select school_id from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (
      select 1 from public.users where id = auth.uid() and role = 'super_admin'
    )
  );

create policy "school staff update students" on public.school_students
  for update
  using (
    school_id in (
      select school_id from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (
      select 1 from public.users where id = auth.uid() and role = 'super_admin'
    )
  );

create policy "school staff delete students" on public.school_students
  for delete
  using (
    school_id in (
      select school_id from public.users
      where id = auth.uid() and role in ('department_admin', 'school_admin', 'super_admin')
    )
    or exists (
      select 1 from public.users where id = auth.uid() and role = 'super_admin'
    )
  );
