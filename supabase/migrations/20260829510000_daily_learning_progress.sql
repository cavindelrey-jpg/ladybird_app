-- ============================================================================
-- greenhills_app/ladybird_app's Daily Learning (Home's "Challenge" tile —
-- Etymology is the first course). Course/lesson content is static Dart
-- data (see lib/data/etymology_course.dart); this table is only the real
-- per-user PROGRESS half — which lessons a user has completed per
-- course. Small enough, and wired to the real XP ledger already, to
-- build for real rather than stub.
-- Same shared database as academia-cameroon; unused there.
-- ============================================================================

create table if not exists public.daily_learning_progress (
  user_id               uuid not null references public.users (id) on delete cascade,
  course_id             text not null,
  completed_lesson_ids  text[] not null default '{}',
  updated_at            timestamptz not null default now(),
  primary key (user_id, course_id)
);

alter table public.daily_learning_progress enable row level security;
create policy "daily_learning_progress_select_own" on public.daily_learning_progress for select
  using (user_id = auth.uid());
create policy "daily_learning_progress_upsert_own" on public.daily_learning_progress for insert
  with check (user_id = auth.uid());
create policy "daily_learning_progress_update_own" on public.daily_learning_progress for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());

alter publication supabase_realtime add table public.daily_learning_progress;
