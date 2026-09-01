-- 20260901030000_school_timetable_slots.sql
-- The official, admin-authored School Timetable. lib/repositories/
-- school_timetable_repository.dart and the full Manage Timetable CRUD UI
-- (features/school/timetable_manager_page.dart) already existed and
-- worked end-to-end -- the repository was just a stub ("School timetable
-- isn't available yet." on every write) because this table never existed.
-- Mirrors models/school_timetable_slot.dart exactly.

create table if not exists public.school_timetable_slots (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.institutions(id) on delete cascade,
  class_level text not null,
  day_of_week smallint not null check (day_of_week between 1 and 6), -- Mon-Sat, see TimetablePage's own comment on why Sunday is excluded
  start_time text not null, -- "08:00"
  end_time text not null,
  subject text not null,
  teacher_name text not null default '',
  room text,
  created_at timestamptz not null default now()
);

create index if not exists school_timetable_slots_school_class_idx
  on public.school_timetable_slots (school_id, class_level);

alter table public.school_timetable_slots enable row level security;

-- Any member of the school can read its timetable (every class's slots --
-- the app itself filters to the signed-in student's own class_level).
create policy "school timetable select" on public.school_timetable_slots
  for select
  using (school_id in (select school_id from public.users where id = auth.uid()));

-- Write access matches AppUser.canManageSchool exactly (hasMinRole(schoolAdmin)),
-- the same client-side gate TimetableManagerPage already checks before
-- ever showing its UI.
create policy "school timetable insert" on public.school_timetable_slots
  for insert
  with check (
    school_id in (
      select school_id from public.users
      where id = auth.uid() and role in ('school_admin', 'super_admin')
    )
  );

create policy "school timetable update" on public.school_timetable_slots
  for update
  using (
    school_id in (
      select school_id from public.users
      where id = auth.uid() and role in ('school_admin', 'super_admin')
    )
  )
  with check (
    school_id in (
      select school_id from public.users
      where id = auth.uid() and role in ('school_admin', 'super_admin')
    )
  );

create policy "school timetable delete" on public.school_timetable_slots
  for delete
  using (
    school_id in (
      select school_id from public.users
      where id = auth.uid() and role in ('school_admin', 'super_admin')
    )
  );

alter publication supabase_realtime add table public.school_timetable_slots;
