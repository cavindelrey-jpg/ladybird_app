-- ============================================================================
-- PublicCourseRepository needs: a course_likes table (mirrors
-- article_likes — courses.like_count exists but had no backing table),
-- a curriculum_icons lookup table (small admin-assigned lookup, keyed by
-- a "category::subject::level::topic" string, not a uuid), and the same
-- kind of atomic RPCs the magazine/club repositories needed for counter
-- + subcollection writes that used to be one Firestore batch/transaction.
-- ============================================================================

create table if not exists public.course_likes (
  course_id   uuid not null references public.courses (id) on delete cascade,
  user_id     uuid not null references public.users (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (course_id, user_id)
);

alter table public.course_likes enable row level security;
create policy "course_likes_select_all" on public.course_likes for select using (true);
create policy "course_likes_insert_self" on public.course_likes for insert with check (user_id = auth.uid());
create policy "course_likes_delete_self" on public.course_likes for delete using (user_id = auth.uid());

create table if not exists public.curriculum_icons (
  key         text primary key,
  emoji       text not null default '',
  image_url   text not null default ''
);

alter table public.curriculum_icons enable row level security;
create policy "curriculum_icons_select_all" on public.curriculum_icons for select using (true);
create policy "curriculum_icons_write_lecturer" on public.curriculum_icons for all
  using (public.has_min_role('lecturer')) with check (public.has_min_role('lecturer'));

create or replace function public.toggle_course_like(p_course_id uuid)
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  v_exists boolean;
begin
  if auth.uid() is null then raise exception 'Must be signed in to like courses.'; end if;
  select exists(select 1 from public.course_likes where course_id = p_course_id and user_id = auth.uid()) into v_exists;
  if v_exists then
    delete from public.course_likes where course_id = p_course_id and user_id = auth.uid();
    update public.courses set like_count = greatest(0, like_count - 1) where id = p_course_id;
    return false;
  else
    insert into public.course_likes (course_id, user_id) values (p_course_id, auth.uid());
    update public.courses set like_count = like_count + 1 where id = p_course_id;
    return true;
  end if;
end;
$$;

create or replace function public.toggle_course_bookmark(p_course_id uuid)
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  v_exists boolean;
begin
  if auth.uid() is null then raise exception 'Must be signed in to bookmark courses.'; end if;
  select exists(select 1 from public.course_bookmarks where course_id = p_course_id and user_id = auth.uid()) into v_exists;
  if v_exists then
    delete from public.course_bookmarks where course_id = p_course_id and user_id = auth.uid();
    return false;
  else
    insert into public.course_bookmarks (course_id, user_id) values (p_course_id, auth.uid());
    return true;
  end if;
end;
$$;

create or replace function public.mark_course_enrolled(p_course_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Must be signed in.'; end if;
  insert into public.course_learners (course_id, user_id) values (p_course_id, auth.uid())
    on conflict (course_id, user_id) do nothing;
  if found then
    update public.courses set enrolled_count = enrolled_count + 1 where id = p_course_id;
  end if;
end;
$$;

-- Recomputes avg_rating/rating_count from all rows after upserting this
-- user's rating — same "recompute the aggregate, avoid incremental drift"
-- approach the original Firestore code used.
create or replace function public.rate_course(p_course_id uuid, p_rating integer)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_avg numeric;
  v_count integer;
begin
  if auth.uid() is null then raise exception 'Must be signed in to rate courses.'; end if;
  insert into public.course_ratings (course_id, user_id, rating) values (p_course_id, auth.uid(), p_rating)
    on conflict (course_id, user_id) do update set rating = excluded.rating;
  select avg(rating), count(*) into v_avg, v_count from public.course_ratings where course_id = p_course_id;
  update public.courses set avg_rating = coalesce(v_avg, 0), rating_count = coalesce(v_count, 0) where id = p_course_id;
end;
$$;

create or replace function public.post_course_comment(
  p_course_id uuid, p_author_id uuid, p_author_name text, p_author_photo_url text, p_body text
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  if auth.uid() is null or auth.uid() <> p_author_id then
    raise exception 'Must be signed in as the comment author.';
  end if;
  insert into public.course_comments (course_id, author_id, author_name, author_photo_url, body)
    values (p_course_id, p_author_id, p_author_name, p_author_photo_url, p_body)
    returning id into v_id;
  update public.courses set comment_count = comment_count + 1 where id = p_course_id;
  return v_id;
end;
$$;

alter publication supabase_realtime add table public.courses;
alter publication supabase_realtime add table public.course_comments;
alter publication supabase_realtime add table public.course_learners;
alter publication supabase_realtime add table public.course_bookmarks;
alter publication supabase_realtime add table public.course_ratings;
