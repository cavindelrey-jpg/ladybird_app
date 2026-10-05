-- ============================================================================
-- MagazineRepository needs several atomic operations Postgres can't do via
-- a plain client-side .update() the way Firestore's FieldValue.increment()
-- + transactions did: toggle-like-and-recount, unique-read-and-award, and
-- the multi-row pendingAuthorXp settlement. Each is a narrow SECURITY
-- DEFINER RPC scoped to exactly the columns it touches, same pattern as
-- increment_library_views/increment_academic_content_views.
-- ============================================================================

create or replace function public.post_article_comment(
  p_article_id uuid, p_author_id uuid, p_author_name text, p_author_photo_url text,
  p_parent_comment_id uuid, p_body text
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  if auth.uid() is null or auth.uid() <> p_author_id then
    raise exception 'Must be signed in as the comment author.';
  end if;
  insert into public.article_comments (article_id, author_id, author_name, author_photo_url, parent_comment_id, body)
    values (p_article_id, p_author_id, p_author_name, p_author_photo_url, p_parent_comment_id, p_body)
    returning id into v_id;
  update public.magazine_articles set comment_count = comment_count + 1 where id = p_article_id;
  return v_id;
end;
$$;

-- Returns the new liked state (true = now liked).
create or replace function public.toggle_article_like(p_article_id uuid)
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  v_exists boolean;
begin
  if auth.uid() is null then raise exception 'Must be signed in to like articles.'; end if;
  select exists(select 1 from public.article_likes where article_id = p_article_id and user_id = auth.uid()) into v_exists;
  if v_exists then
    delete from public.article_likes where article_id = p_article_id and user_id = auth.uid();
    update public.magazine_articles set like_count = greatest(0, like_count - 1) where id = p_article_id;
    return false;
  else
    insert into public.article_likes (article_id, user_id) values (p_article_id, auth.uid());
    update public.magazine_articles set like_count = like_count + 1 where id = p_article_id;
    return true;
  end if;
end;
$$;

-- No-op if this reader has already read this article (matches the old
-- transaction's exact semantics: 2 XP per unique reader, never repeated).
create or replace function public.record_article_read(p_article_id uuid, p_reader_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into public.article_reads (article_id, user_id) values (p_article_id, p_reader_id)
    on conflict (article_id, user_id) do nothing;
  if found then
    update public.magazine_articles
      set read_count = read_count + 1, pending_author_xp = pending_author_xp + 2
      where id = p_article_id;
  end if;
end;
$$;

-- Zeroes every pending-XP article this author owns and returns the total
-- owed, atomically — so a crash between "read the total" and "zero the
-- rows" can't double-pay or lose XP.
create or replace function public.settle_pending_author_xp(p_author_id uuid)
returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_total integer;
begin
  if auth.uid() is null or auth.uid() <> p_author_id then
    raise exception 'Must be signed in as the author.';
  end if;
  select coalesce(sum(pending_author_xp), 0) into v_total
    from public.magazine_articles where author_id = p_author_id and pending_author_xp > 0;
  update public.magazine_articles set pending_author_xp = 0
    where author_id = p_author_id and pending_author_xp > 0;
  return v_total;
end;
$$;

create or replace function public.toggle_article_bookmark(p_article_id uuid)
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  v_exists boolean;
begin
  if auth.uid() is null then raise exception 'Must be signed in to bookmark articles.'; end if;
  select exists(select 1 from public.article_bookmarks where article_id = p_article_id and user_id = auth.uid()) into v_exists;
  if v_exists then
    delete from public.article_bookmarks where article_id = p_article_id and user_id = auth.uid();
    return false;
  else
    insert into public.article_bookmarks (article_id, user_id) values (p_article_id, auth.uid());
    return true;
  end if;
end;
$$;
