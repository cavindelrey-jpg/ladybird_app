-- ============================================================================
-- greenhills_app/ladybird_app's Clubs remake, on top of the shared
-- clubs/club_members/club_join_requests/club_messages tables:
--   - clubs: thumbnail_url (separate from banner_url), and a denormalized
--     lastMessage* preview so a club can appear in a merged Messages
--     inbox alongside 1:1 conversations.
--   - club_members: last_active_at, a cheap presence heartbeat for a real
--     (not fabricated) "X members online" hero stat.
--   - Four new feature areas, each its own table(s): Feed (club_posts +
--     comments + likes), Discussions (club_discussions + replies + likes,
--     Q&A with a mark-able best answer that awards bonus XP), Resources
--     (club_resources), Events (club_events + rsvps).
-- Same shared tables/database as academia-cameroon; unused there.
-- ============================================================================

alter table public.clubs
  add column if not exists thumbnail_url text,
  add column if not exists last_message_text text,
  add column if not exists last_message_sender_id uuid references public.users (id) on delete set null,
  add column if not exists last_message_at timestamptz;

alter table public.club_members
  add column if not exists last_active_at timestamptz;

-- Shared helper for "is this club member at least a moderator" checks
-- below, mirrors clubMemberRole()/isClubMember() in firestore.rules.
create or replace function public.is_club_staff(p_club_id uuid)
returns boolean
language sql stable as $$
  select exists(
    select 1 from public.club_members
    where club_id = p_club_id and user_id = auth.uid() and role in ('admin', 'moderator')
  );
$$;

-- ── Feed (posts) ─────────────────────────────────────────────────────────

create table if not exists public.club_posts (
  id               uuid primary key default gen_random_uuid(),
  club_id          uuid not null references public.clubs (id) on delete cascade,
  author_id        uuid references public.users (id) on delete set null,
  author_name      text,
  author_photo_url text,
  is_announcement  boolean not null default false,
  title            text not null default '',
  body             text not null default '',
  image_url        text,
  like_count       integer not null default 0,
  comment_count    integer not null default 0,
  created_at       timestamptz not null default now()
);
create index if not exists club_posts_club_id_idx on public.club_posts (club_id);
alter table public.club_posts enable row level security;
create policy "club_posts_select_all" on public.club_posts for select using (true);
create policy "club_posts_insert_authenticated" on public.club_posts for insert with check (auth.uid() is not null);
create policy "club_posts_update_own_or_staff" on public.club_posts for update
  using (author_id = auth.uid() or public.is_club_staff(club_id));
create policy "club_posts_delete_own_or_staff" on public.club_posts for delete
  using (author_id = auth.uid() or public.is_club_staff(club_id));

create table if not exists public.club_post_likes (
  post_id  uuid not null references public.club_posts (id) on delete cascade,
  user_id  uuid not null references public.users (id) on delete cascade,
  liked_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
alter table public.club_post_likes enable row level security;
create policy "club_post_likes_select_all" on public.club_post_likes for select using (true);

create table if not exists public.club_post_comments (
  id               uuid primary key default gen_random_uuid(),
  post_id          uuid not null references public.club_posts (id) on delete cascade,
  author_id        uuid references public.users (id) on delete set null,
  author_name      text,
  author_photo_url text,
  text             text not null default '',
  created_at       timestamptz not null default now()
);
create index if not exists club_post_comments_post_id_idx on public.club_post_comments (post_id);
alter table public.club_post_comments enable row level security;
create policy "club_post_comments_select_all" on public.club_post_comments for select using (true);
create policy "club_post_comments_insert_own" on public.club_post_comments for insert with check (author_id = auth.uid());

create or replace function public.toggle_club_post_like(p_post_id uuid)
returns boolean
language plpgsql security definer set search_path = public as $$
declare v_exists boolean;
begin
  if auth.uid() is null then raise exception 'Must be signed in to like posts.'; end if;
  select exists(select 1 from public.club_post_likes where post_id = p_post_id and user_id = auth.uid()) into v_exists;
  if v_exists then
    delete from public.club_post_likes where post_id = p_post_id and user_id = auth.uid();
    update public.club_posts set like_count = greatest(0, like_count - 1) where id = p_post_id;
    return false;
  else
    insert into public.club_post_likes (post_id, user_id) values (p_post_id, auth.uid());
    update public.club_posts set like_count = like_count + 1 where id = p_post_id;
    return true;
  end if;
end;
$$;

create or replace function public.add_club_post_comment(
  p_post_id uuid, p_author_name text, p_author_photo_url text, p_text text
) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Must be signed in to comment.'; end if;
  insert into public.club_post_comments (post_id, author_id, author_name, author_photo_url, text)
    values (p_post_id, auth.uid(), p_author_name, p_author_photo_url, p_text)
    returning id into v_id;
  update public.club_posts set comment_count = comment_count + 1 where id = p_post_id;
  return v_id;
end;
$$;

-- ── Discussions (Q&A with best-answer + XP) ───────────────────────────────

create table if not exists public.club_discussions (
  id                    uuid primary key default gen_random_uuid(),
  club_id               uuid not null references public.clubs (id) on delete cascade,
  author_id             uuid references public.users (id) on delete set null,
  author_name           text,
  author_photo_url      text,
  title                 text not null default '',
  body                  text not null default '',
  tag                   text,
  reply_count           integer not null default 0,
  view_count            integer not null default 0,
  like_count            integer not null default 0,
  best_answer_reply_id  uuid,
  created_at            timestamptz not null default now()
);
create index if not exists club_discussions_club_id_idx on public.club_discussions (club_id);
alter table public.club_discussions enable row level security;
create policy "club_discussions_select_all" on public.club_discussions for select using (true);
create policy "club_discussions_insert_own" on public.club_discussions for insert with check (author_id = auth.uid());
create policy "club_discussions_update_own_or_staff" on public.club_discussions for update
  using (author_id = auth.uid() or public.is_club_staff(club_id));
create policy "club_discussions_delete_own_or_staff" on public.club_discussions for delete
  using (author_id = auth.uid() or public.is_club_staff(club_id));

create table if not exists public.club_discussion_likes (
  discussion_id  uuid not null references public.club_discussions (id) on delete cascade,
  user_id        uuid not null references public.users (id) on delete cascade,
  liked_at       timestamptz not null default now(),
  primary key (discussion_id, user_id)
);
alter table public.club_discussion_likes enable row level security;
create policy "club_discussion_likes_select_all" on public.club_discussion_likes for select using (true);

create table if not exists public.club_discussion_replies (
  id                        uuid primary key default gen_random_uuid(),
  discussion_id             uuid not null references public.club_discussions (id) on delete cascade,
  author_id                 uuid references public.users (id) on delete set null,
  author_name               text,
  author_photo_url          text,
  author_is_staff           boolean not null default false,
  body                      text not null default '',
  like_count                integer not null default 0,
  is_best_answer            boolean not null default false,
  attached_resource_id      uuid,
  attached_resource_title   text,
  attached_resource_url     text,
  created_at                timestamptz not null default now()
);
create index if not exists club_discussion_replies_discussion_id_idx on public.club_discussion_replies (discussion_id);
alter table public.club_discussion_replies enable row level security;
create policy "club_discussion_replies_select_all" on public.club_discussion_replies for select using (true);
create policy "club_discussion_replies_insert_own" on public.club_discussion_replies for insert with check (author_id = auth.uid());
create policy "club_discussion_replies_update_own_or_staff" on public.club_discussion_replies for update
  using (
    author_id = auth.uid()
    or exists (select 1 from public.club_discussions d where d.id = discussion_id and public.is_club_staff(d.club_id))
    or exists (select 1 from public.club_discussions d where d.id = discussion_id and d.author_id = auth.uid())
  );
create policy "club_discussion_replies_delete_own_or_staff" on public.club_discussion_replies for delete
  using (
    author_id = auth.uid()
    or exists (select 1 from public.club_discussions d where d.id = discussion_id and public.is_club_staff(d.club_id))
  );

create table if not exists public.club_discussion_reply_likes (
  reply_id  uuid not null references public.club_discussion_replies (id) on delete cascade,
  user_id   uuid not null references public.users (id) on delete cascade,
  liked_at  timestamptz not null default now(),
  primary key (reply_id, user_id)
);
alter table public.club_discussion_reply_likes enable row level security;
create policy "club_discussion_reply_likes_select_all" on public.club_discussion_reply_likes for select using (true);

create or replace function public.increment_discussion_view(p_discussion_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.club_discussions set view_count = view_count + 1 where id = p_discussion_id;
end;
$$;

create or replace function public.add_club_discussion_reply(
  p_discussion_id uuid, p_author_name text, p_author_photo_url text, p_author_is_staff boolean, p_body text,
  p_attached_resource_id uuid default null, p_attached_resource_title text default null, p_attached_resource_url text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Must be signed in to reply.'; end if;
  insert into public.club_discussion_replies (
    discussion_id, author_id, author_name, author_photo_url, author_is_staff, body,
    attached_resource_id, attached_resource_title, attached_resource_url
  ) values (
    p_discussion_id, auth.uid(), p_author_name, p_author_photo_url, p_author_is_staff, p_body,
    p_attached_resource_id, p_attached_resource_title, p_attached_resource_url
  ) returning id into v_id;
  update public.club_discussions set reply_count = reply_count + 1 where id = p_discussion_id;
  return v_id;
end;
$$;

-- Only the discussion's own author or a club admin/moderator may call
-- this (mirrors firestore.rules' equivalent check) -- moving the mark to
-- a different reply first un-marks the old one so exactly one best
-- answer exists per discussion at a time.
create or replace function public.mark_club_best_answer(p_discussion_id uuid, p_reply_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_discussion_author uuid;
  v_club_id uuid;
begin
  select author_id, club_id into v_discussion_author, v_club_id
    from public.club_discussions where id = p_discussion_id for update;
  if v_discussion_author is null and v_club_id is null then
    raise exception 'Discussion not found';
  end if;
  if auth.uid() is null or (auth.uid() <> v_discussion_author and not public.is_club_staff(v_club_id)) then
    raise exception 'Only the question author or a club moderator can mark a best answer.';
  end if;

  update public.club_discussion_replies set is_best_answer = false
    where discussion_id = p_discussion_id and is_best_answer = true and id <> p_reply_id;
  update public.club_discussion_replies set is_best_answer = true where id = p_reply_id;
  update public.club_discussions set best_answer_reply_id = p_reply_id where id = p_discussion_id;
end;
$$;

create or replace function public.toggle_club_discussion_like(p_discussion_id uuid)
returns boolean
language plpgsql security definer set search_path = public as $$
declare v_exists boolean;
begin
  if auth.uid() is null then raise exception 'Must be signed in to like discussions.'; end if;
  select exists(select 1 from public.club_discussion_likes where discussion_id = p_discussion_id and user_id = auth.uid()) into v_exists;
  if v_exists then
    delete from public.club_discussion_likes where discussion_id = p_discussion_id and user_id = auth.uid();
    update public.club_discussions set like_count = greatest(0, like_count - 1) where id = p_discussion_id;
    return false;
  else
    insert into public.club_discussion_likes (discussion_id, user_id) values (p_discussion_id, auth.uid());
    update public.club_discussions set like_count = like_count + 1 where id = p_discussion_id;
    return true;
  end if;
end;
$$;

create or replace function public.toggle_club_discussion_reply_like(p_reply_id uuid)
returns boolean
language plpgsql security definer set search_path = public as $$
declare v_exists boolean;
begin
  if auth.uid() is null then raise exception 'Must be signed in to like replies.'; end if;
  select exists(select 1 from public.club_discussion_reply_likes where reply_id = p_reply_id and user_id = auth.uid()) into v_exists;
  if v_exists then
    delete from public.club_discussion_reply_likes where reply_id = p_reply_id and user_id = auth.uid();
    update public.club_discussion_replies set like_count = greatest(0, like_count - 1) where id = p_reply_id;
    return false;
  else
    insert into public.club_discussion_reply_likes (reply_id, user_id) values (p_reply_id, auth.uid());
    update public.club_discussion_replies set like_count = like_count + 1 where id = p_reply_id;
    return true;
  end if;
end;
$$;

-- ── Resources ──────────────────────────────────────────────────────────

create table if not exists public.club_resources (
  id                  uuid primary key default gen_random_uuid(),
  club_id             uuid not null references public.clubs (id) on delete cascade,
  title               text not null default '',
  description         text,
  url                 text not null default '',
  is_file             boolean not null default false,
  uploader_id         uuid references public.users (id) on delete set null,
  uploader_name       text,
  uploader_photo_url  text,
  created_at          timestamptz not null default now()
);
create index if not exists club_resources_club_id_idx on public.club_resources (club_id);
alter table public.club_resources enable row level security;
create policy "club_resources_select_all" on public.club_resources for select using (true);
create policy "club_resources_insert_own" on public.club_resources for insert with check (uploader_id = auth.uid());
create policy "club_resources_delete_own_or_staff" on public.club_resources for delete
  using (uploader_id = auth.uid() or public.is_club_staff(club_id));

-- ── Events ─────────────────────────────────────────────────────────────

create table if not exists public.club_events (
  id            uuid primary key default gen_random_uuid(),
  club_id       uuid not null references public.clubs (id) on delete cascade,
  title         text not null default '',
  description   text,
  start_at      timestamptz not null default now(),
  location      text,
  creator_id    uuid references public.users (id) on delete set null,
  creator_name  text,
  rsvp_count    integer not null default 0,
  created_at    timestamptz not null default now()
);
create index if not exists club_events_club_id_idx on public.club_events (club_id);
alter table public.club_events enable row level security;
create policy "club_events_select_all" on public.club_events for select using (true);
create policy "club_events_write_staff" on public.club_events for all
  using (public.is_club_staff(club_id)) with check (public.is_club_staff(club_id));

create table if not exists public.club_event_rsvps (
  event_id  uuid not null references public.club_events (id) on delete cascade,
  user_id   uuid not null references public.users (id) on delete cascade,
  rsvp_at   timestamptz not null default now(),
  primary key (event_id, user_id)
);
alter table public.club_event_rsvps enable row level security;
create policy "club_event_rsvps_select_all" on public.club_event_rsvps for select using (true);
create policy "club_event_rsvps_insert_self" on public.club_event_rsvps for insert with check (user_id = auth.uid());
create policy "club_event_rsvps_delete_self" on public.club_event_rsvps for delete using (user_id = auth.uid());

create or replace function public.toggle_club_event_rsvp(p_event_id uuid, p_going boolean)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Must be signed in to RSVP.'; end if;
  if p_going then
    insert into public.club_event_rsvps (event_id, user_id) values (p_event_id, auth.uid())
      on conflict (event_id, user_id) do nothing;
    if found then
      update public.club_events set rsvp_count = rsvp_count + 1 where id = p_event_id;
    end if;
  else
    delete from public.club_event_rsvps where event_id = p_event_id and user_id = auth.uid();
    if found then
      update public.club_events set rsvp_count = greatest(0, rsvp_count - 1) where id = p_event_id;
    end if;
  end if;
end;
$$;
