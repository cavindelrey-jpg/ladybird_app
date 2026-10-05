-- ============================================================================
-- More tables the rewritten repositories use .stream() against (same
-- reasoning as 20260829150000 for `users`) — without being added to the
-- supabase_realtime publication, these streams silently never emit.
-- ============================================================================

alter publication supabase_realtime add table public.academic_content;
alter publication supabase_realtime add table public.content_saves;
alter publication supabase_realtime add table public.content_recent_views;
alter publication supabase_realtime add table public.institutions;
