-- 20261004020000_fix_school_students_roster_rls.sql
-- Fix RLS policies on public.school_students: use institution_id on public.users
-- (users has no school_id column, which caused student queries to error and fall back).

drop policy if exists "school staff select students" on public.school_students;
create policy "school staff select students" on public.school_students
  for select
  using (
    school_id in (
      select coalesce(institution_id, id) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (
      select 1 from public.users where id = auth.uid() and role = 'super_admin'
    )
  );

drop policy if exists "school staff insert students" on public.school_students;
create policy "school staff insert students" on public.school_students
  for insert
  with check (
    school_id in (
      select coalesce(institution_id, id) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (
      select 1 from public.users where id = auth.uid() and role = 'super_admin'
    )
  );

drop policy if exists "school staff update students" on public.school_students;
create policy "school staff update students" on public.school_students
  for update
  using (
    school_id in (
      select coalesce(institution_id, id) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (
      select 1 from public.users where id = auth.uid() and role = 'super_admin'
    )
  );

drop policy if exists "school staff delete students" on public.school_students;
create policy "school staff delete students" on public.school_students
  for delete
  using (
    school_id in (
      select coalesce(institution_id, id) from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (
      select 1 from public.users where id = auth.uid() and role = 'super_admin'
    )
  );
