-- 20260903150000_fix_school_marks_timetable_tenant_leak.sql
-- CRITICAL FIX: school_marks/school_timetable_slots' RLS policies were
-- written as `school_id in (select school_id from public.users where
-- id = auth.uid() and role in (...))` -- but public.users has no
-- `school_id` column (it's `institution_id`, see
-- 20260828060000_initial_schema.sql / redeem_school_voucher()). Postgres
-- didn't error on the missing column: since the subquery's own FROM
-- (users) has no school_id, it silently resolved the unqualified
-- `school_id` reference to the OUTER row's school_id instead (confirmed
-- live via pg_policies: qual shows `SELECT school_marks.school_id FROM
-- users WHERE ...`). That collapses "same school" into "any row exists in
-- users matching this role at all" -- true for a staff member of ANY
-- school. The "school timetable select" policy is worse: it drops the
-- role check too, so it degenerates to "auth.uid() is not null", visible
-- in its qual having no role condition at all.
--
-- Net effect before this fix: any signed-in lecturer/department_admin/
-- school_admin/super_admin could read AND write every school's marks and
-- timetable data, and any signed-in user at all could read every
-- school's timetable -- not scoped to their own school as intended.
--
-- Fix: reference the real column, public.users.institution_id.

drop policy if exists "school marks select" on public.school_marks;
create policy "school marks select" on public.school_marks
  for select
  using (
    student_id = auth.uid()
    or school_id in (
      select institution_id from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
  );

drop policy if exists "school marks insert" on public.school_marks;
create policy "school marks insert" on public.school_marks
  for insert
  with check (
    school_id in (
      select institution_id from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
  );

drop policy if exists "school marks update" on public.school_marks;
create policy "school marks update" on public.school_marks
  for update
  using (
    school_id in (
      select institution_id from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
  )
  with check (
    school_id in (
      select institution_id from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
  );

drop policy if exists "school marks delete" on public.school_marks;
create policy "school marks delete" on public.school_marks
  for delete
  using (
    school_id in (
      select institution_id from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
  );

drop policy if exists "school timetable select" on public.school_timetable_slots;
create policy "school timetable select" on public.school_timetable_slots
  for select
  using (school_id in (select institution_id from public.users where id = auth.uid()));

drop policy if exists "school timetable insert" on public.school_timetable_slots;
create policy "school timetable insert" on public.school_timetable_slots
  for insert
  with check (
    school_id in (
      select institution_id from public.users
      where id = auth.uid() and role in ('school_admin', 'super_admin')
    )
  );

drop policy if exists "school timetable update" on public.school_timetable_slots;
create policy "school timetable update" on public.school_timetable_slots
  for update
  using (
    school_id in (
      select institution_id from public.users
      where id = auth.uid() and role in ('school_admin', 'super_admin')
    )
  )
  with check (
    school_id in (
      select institution_id from public.users
      where id = auth.uid() and role in ('school_admin', 'super_admin')
    )
  );

drop policy if exists "school timetable delete" on public.school_timetable_slots;
create policy "school timetable delete" on public.school_timetable_slots
  for delete
  using (
    school_id in (
      select institution_id from public.users
      where id = auth.uid() and role in ('school_admin', 'super_admin')
    )
  );
