-- 20260904000000_teacher_authorization_enforcement.sql
-- Closes the gap 20260903150000's own comment admits to: school_marks
-- INSERT/UPDATE only ever checked role+institution_id ("any staff member
-- of this school"), never the fine-grained (subject, class_level)
-- authorization that AppUser.canRecordMarksFor already enforces
-- client-side (lib/models/app_user.dart:288-292, including its
-- class-master bypass: classMasterOfClass == classLevel). This makes
-- that same check DB-authoritative, mirroring homework's insert policy
-- (20260903160000_homework_and_calendar_events.sql) -- including its own
-- documented lesson: every column reference below is qualified with its
-- table name (`school_marks.subject`, never a bare `subject`) to avoid
-- the silent-auto-correlation bug 20260903150000 had to fix (a bare
-- `school_id` in a subquery over `users`, which has no such column, was
-- auto-correlating to the outer row instead of erroring).
--
-- A prior, never-applied draft of this migration reintroduced that exact
-- bug (`select school_id from public.users`, a column that doesn't
-- exist -- it's `institution_id`) and dropped the class-master bypass.
-- Rewritten from scratch against the current live school_marks policies
-- instead. school_timetable_slots is untouched here: its insert/update
-- policies are already admin-only (school_admin/super_admin), which
-- matches "Admin manages the timetable" -- no per-teacher slot ownership
-- exists to authorize against.

create or replace function public.is_teacher_authorized_for_marks(
  p_user_id uuid, p_subject text, p_class_level text
) returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.users u
    where u.id = p_user_id
      and (
        u.class_master_of_class = p_class_level
        or exists (
          select 1 from jsonb_array_elements(u.teaching_assignments) ta
          where ta ->> 'subject' = p_subject
            and ta ->> 'classLevel' = p_class_level
        )
      )
  );
$$;

drop policy if exists "school marks insert" on public.school_marks;
create policy "school marks insert" on public.school_marks
  for insert
  with check (
    school_marks.school_id in (
      select institution_id from public.users
      where id = auth.uid() and role in ('department_admin', 'school_admin', 'super_admin')
    )
    or (
      school_marks.school_id in (
        select institution_id from public.users where id = auth.uid() and role = 'lecturer'
      )
      and public.is_teacher_authorized_for_marks(auth.uid(), school_marks.subject, school_marks.class_level)
    )
  );

drop policy if exists "school marks update" on public.school_marks;
create policy "school marks update" on public.school_marks
  for update
  using (
    school_marks.school_id in (
      select institution_id from public.users
      where id = auth.uid() and role in ('department_admin', 'school_admin', 'super_admin')
    )
    or (
      school_marks.school_id in (
        select institution_id from public.users where id = auth.uid() and role = 'lecturer'
      )
      and public.is_teacher_authorized_for_marks(auth.uid(), school_marks.subject, school_marks.class_level)
    )
  )
  with check (
    school_marks.school_id in (
      select institution_id from public.users
      where id = auth.uid() and role in ('department_admin', 'school_admin', 'super_admin')
    )
    or (
      school_marks.school_id in (
        select institution_id from public.users where id = auth.uid() and role = 'lecturer'
      )
      and public.is_teacher_authorized_for_marks(auth.uid(), school_marks.subject, school_marks.class_level)
    )
  );
