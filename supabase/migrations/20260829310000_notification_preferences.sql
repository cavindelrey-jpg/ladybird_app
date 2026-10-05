-- ============================================================================
-- users/{uid}/settings/notifications (a singleton preferences doc) was a
-- known gap flagged in the original extended-schema pass — a different
-- subcollection name ("settings") that wasn't in the original export
-- list. Adding it now while finishing NotificationRepository.
-- ============================================================================

create table if not exists public.notification_preferences (
  user_id        uuid primary key references public.users (id) on delete cascade,
  announcements  boolean not null default true,
  comments       boolean not null default true,
  replies        boolean not null default true,
  new_articles   boolean not null default true
);

alter table public.notification_preferences enable row level security;
create policy "notification_preferences_select_own" on public.notification_preferences for select using (user_id = auth.uid());
create policy "notification_preferences_upsert_own" on public.notification_preferences for insert with check (user_id = auth.uid());
create policy "notification_preferences_update_own" on public.notification_preferences for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());

alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.notification_preferences;
