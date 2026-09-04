-- 20260904000009_enable_library_folders_realtime.sql
-- "Couldn't load folders — RealtimeSubscribeException(status:
-- channelError, ... table: library_folders...)" -- same root cause as
-- 20260901010000_enable_club_realtime.sql: lib/repositories/
-- library_folder_repository.dart uses SupabaseQueryBuilder.stream()
-- (Realtime postgres_changes) against library_folders (and, on the same
-- repository, academic_content directly for folder-scoped content), but
-- a table isn't automatically added to the `supabase_realtime`
-- publication just by being created -- this one apparently never was.
-- Adds both, skipping any already present so this is safe to re-run.

do $$
declare
  t text;
begin
  foreach t in array array[
    'library_folders',
    'academic_content'
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
