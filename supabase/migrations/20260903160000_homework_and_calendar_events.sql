-- 20260903160000_homework_and_calendar_events.sql
-- Homework Management (spec items 3, 5, 6) and School Calendar / Activities
-- (spec item 7 / the WA0015 mockup). Both greenfield -- see the "Final
-- Implementation Instructions" school-operations spec.
--
-- Lesson from 20260903150000's fix: every RLS clause below explicitly
-- qualifies the protected table's own columns with its table name (e.g.
-- `homework.school_id`, never a bare `school_id`) wherever a correlated
-- subquery is also in scope. That's what silently broke school_marks/
-- school_timetable_slots -- a bare column Postgres couldn't find in the
-- subquery's own FROM list got auto-correlated to the outer row instead of
-- raising an error. Explicit qualification here makes that class of bug
-- impossible to reintroduce by accident.
--
-- homework's write policy is the first DB-enforced per-(subject,class_level)
-- teacher permission in this project -- school_marks' own migration comment
-- admits that finer check has always been client-side only. It reads
-- AppUser.teachingAssignments' jsonb shape directly (keys are 'subject' and
-- 'classLevel' -- see TeachingAssignment.toMap(), NOT snake_case; the
-- Supabase client serializes the Dart Map's keys verbatim).

create table if not exists public.homework (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.institutions(id) on delete cascade,
  class_level text not null,
  subject text not null,
  teacher_id uuid not null references public.users(id) on delete cascade,
  title text not null,
  description text not null default '',
  body_delta jsonb,
  homework_type text not null default 'assignment',
  due_at timestamptz not null,
  attachment_url text,
  attachment_name text,
  required_materials text[] not null default '{}',
  notify boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists homework_school_class_idx on public.homework (school_id, class_level);
create index if not exists homework_teacher_idx on public.homework (teacher_id);
create index if not exists homework_due_at_idx on public.homework (due_at);

alter table public.homework enable row level security;

-- A student sees homework for their own class; any staff member of the
-- school sees all of it (mirrors school_marks' "staff = one trust domain
-- per school" precedent).
create policy "homework select" on public.homework
  for select
  using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.institution_id = homework.school_id
        and (u.class_level = homework.class_level
             or u.role in ('lecturer', 'department_admin', 'school_admin', 'super_admin'))
    )
  );

-- Real DB enforcement of "a teacher can only set homework for a
-- (subject, class_level) pair they're actually assigned to" -- admins
-- bypass, matching AppUser.canManageHomeworkFor's client-side mirror.
create policy "homework insert" on public.homework
  for insert
  with check (
    teacher_id = auth.uid()
    and exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.institution_id = homework.school_id
        and (
          u.role in ('school_admin', 'super_admin')
          or (
            u.role = 'lecturer'
            and exists (
              select 1 from jsonb_array_elements(u.teaching_assignments) ta
              where ta ->> 'subject' = homework.subject
                and ta ->> 'classLevel' = homework.class_level
            )
          )
        )
    )
  );

-- Editing/deleting your own homework, or any school_admin+ of that school --
-- deliberately not re-checking the (subject, class_level) assignment here,
-- since an admin reassigning a teacher's classes later shouldn't retroactively
-- lock the teacher out of homework they already own.
create policy "homework update" on public.homework
  for update
  using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.institution_id = homework.school_id
        and (u.role in ('school_admin', 'super_admin') or homework.teacher_id = auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.institution_id = homework.school_id
        and (u.role in ('school_admin', 'super_admin') or homework.teacher_id = auth.uid())
    )
  );

create policy "homework delete" on public.homework
  for delete
  using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.institution_id = homework.school_id
        and (u.role in ('school_admin', 'super_admin') or homework.teacher_id = auth.uid())
    )
  );

alter publication supabase_realtime add table public.homework;

-- School Calendar / Activities -- admin-authored, school-wide (or
-- class-scoped) events. affected_classes empty = every class.
create table if not exists public.school_calendar_events (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.institutions(id) on delete cascade,
  title text not null,
  description text not null default '',
  category text not null default 'academic'
    check (category in ('academic', 'exam', 'meeting', 'sports', 'holiday')),
  start_date date not null,
  end_date date not null,
  all_day boolean not null default true,
  start_time text,
  end_time text,
  location text,
  affected_classes text[] not null default '{}',
  notify_parents boolean not null default true,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists school_calendar_events_school_date_idx
  on public.school_calendar_events (school_id, start_date);

alter table public.school_calendar_events enable row level security;

create policy "school calendar select" on public.school_calendar_events
  for select
  using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.institution_id = school_calendar_events.school_id
    )
  );

create policy "school calendar insert" on public.school_calendar_events
  for insert
  with check (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.institution_id = school_calendar_events.school_id
        and u.role in ('school_admin', 'super_admin')
    )
  );

create policy "school calendar update" on public.school_calendar_events
  for update
  using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.institution_id = school_calendar_events.school_id
        and u.role in ('school_admin', 'super_admin')
    )
  )
  with check (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.institution_id = school_calendar_events.school_id
        and u.role in ('school_admin', 'super_admin')
    )
  );

create policy "school calendar delete" on public.school_calendar_events
  for delete
  using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.institution_id = school_calendar_events.school_id
        and u.role in ('school_admin', 'super_admin')
    )
  );

alter publication supabase_realtime add table public.school_calendar_events;
