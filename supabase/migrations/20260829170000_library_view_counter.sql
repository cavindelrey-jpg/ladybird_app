-- ============================================================================
-- LibraryRepository.incrementViews() needs to bump library_items.views for
-- ANY signed-in reader, not just lecturer+ (who own library_items' write
-- policy). Firestore's FieldValue.increment() did this atomically without
-- needing a write grant beyond the update itself; Postgres has no
-- equivalent from the client, so this is a narrow SECURITY DEFINER RPC
-- scoped to exactly one column, not a general write bypass.
-- ============================================================================

create or replace function public.increment_library_views(p_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Must be signed in.';
  end if;
  update public.library_items set views = views + 1 where id = p_id;
end;
$$;
