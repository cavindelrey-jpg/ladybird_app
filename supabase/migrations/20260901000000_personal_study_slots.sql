-- 20260901000000_personal_study_slots.sql
-- production_plan.md §5's Personal Study Timetable. The Dart side
-- (lib/repositories/personal_study_repository.dart, lib/models/
-- personal_study_slot.dart) already ships against this table, but it was
-- never actually created in the live project -- "My Study Timetable"
-- fails on load with:
--   PostgrestException(message: Could not find the table
--   'public.personal_study_slots' in the schema cache, code: PGRST205)
--
-- Owner-only, per-user data -- a plain auth.uid() = user_id RLS check on
-- every op, no security-definer RPC needed since there's no cross-user
-- access at all (mirrors content_saves/content_recent_views' pattern).

create table if not exists public.personal_study_slots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 1 and 7), -- 1=Mon..7=Sun
  start_time text not null, -- "18:00"
  end_time text not null,
  activity text not null,
  subject text, -- optional free-text link to kAcademicSubjects
  created_at timestamptz not null default now()
);

create index if not exists personal_study_slots_user_id_idx
  on public.personal_study_slots (user_id);

alter table public.personal_study_slots enable row level security;

create policy "own study slots select"
  on public.personal_study_slots for select
  using (auth.uid() = user_id);

create policy "own study slots insert"
  on public.personal_study_slots for insert
  with check (auth.uid() = user_id);

create policy "own study slots update"
  on public.personal_study_slots for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "own study slots delete"
  on public.personal_study_slots for delete
  using (auth.uid() = user_id);

-- watchAll()/watchToday() use SupabaseQueryBuilder.stream(), which needs
-- the table in the realtime publication.
alter publication supabase_realtime add table public.personal_study_slots;
