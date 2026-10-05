-- 20260909130000_class_master_timetable_access.sql
-- Class masters could not manage their own class's timetable at all --
-- write access to school_timetable_slots was school_admin+ only. The
-- user explicitly asked for "class master sets the timetable for my own
-- class" as a distinct flow from full school-admin timetable control.
-- Mirrors the class-master bypass already granted for school_marks (see
-- 20260903150000_fix_school_marks_timetable_tenant_leak.sql).
--
-- Rewritten using the existing current_institution_id()/has_min_role()
-- SECURITY DEFINER helpers instead of repeating the inline subquery, so
-- this doesn't reintroduce the exact "unqualified column silently
-- resolves to the outer row" class of bug that 20260903150000 fixed.

drop policy if exists "school timetable insert" on public.school_timetable_slots;
create policy "school timetable insert" on public.school_timetable_slots
  for insert
  with check (
    school_id = current_institution_id()
    and (
      has_min_role('school_admin'::user_role)
      or class_level = (select class_master_of_class from public.users where id = auth.uid())
    )
  );

drop policy if exists "school timetable update" on public.school_timetable_slots;
create policy "school timetable update" on public.school_timetable_slots
  for update
  using (
    school_id = current_institution_id()
    and (
      has_min_role('school_admin'::user_role)
      or class_level = (select class_master_of_class from public.users where id = auth.uid())
    )
  )
  with check (
    school_id = current_institution_id()
    and (
      has_min_role('school_admin'::user_role)
      or class_level = (select class_master_of_class from public.users where id = auth.uid())
    )
  );

drop policy if exists "school timetable delete" on public.school_timetable_slots;
create policy "school timetable delete" on public.school_timetable_slots
  for delete
  using (
    school_id = current_institution_id()
    and (
      has_min_role('school_admin'::user_role)
      or class_level = (select class_master_of_class from public.users where id = auth.uid())
    )
  );
