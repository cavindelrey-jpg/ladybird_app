-- Club Feed and Discussions fail to load with:
--   RealtimeSubscribeException(status: channelError, ... Please check
--   Realtime is enabled for the given connect parameters: [event: *,
--   schema: public, table: ...
--
-- lib/repositories/club_repository.dart uses SupabaseQueryBuilder.stream()
-- (Realtime postgres_changes) against every club_* table, but the 10 new
-- tables added by 20260829450000_clubs_remake.sql were never added to the
-- supabase_realtime publication -- only the original 4 club tables were
-- (see 20260829230000_enable_realtime_clubs.sql, which predates the
-- remake). Same bug class as library_folders earlier in this migration
-- set. Adds all of them, skipping any already present so this is safe
-- to re-run.

do $$
declare
  t text;
begin
  foreach t in array array[
    'clubs',
    'club_members',
    'club_posts',
    'club_post_likes',
    'club_post_comments',
    'club_discussions',
    'club_discussion_likes',
    'club_discussion_replies',
    'club_discussion_reply_likes',
    'club_events',
    'club_event_rsvps',
    'club_resources',
    'club_join_requests',
    'club_messages'
  ]
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
