-- 20261002030000_class_groups.sql
-- Class group chats for class masters (QA pass 2026-10-02), built on the
-- existing clubs + club_members + club_messages stack -- which already
-- has a working group chat UI and member-only message RLS -- instead of
-- retrofitting groups into the 1:1 direct-message RPCs shared with the
-- sibling apps.
--
-- A class group is a club with class_level set. It can only be created
-- through create_class_group() by that class's master or a school admin,
-- and is auto-populated with every student in the class.
--
-- Also fixes club_members_insert_self, which was just `user_id = uid()`:
-- anyone could insert themselves into ANY club -- skipping
-- requires_approval -- and then read its messages. Self-join is now only
-- allowed for open clubs; approval-gated clubs go through the existing
-- join-request approval RPC (SECURITY DEFINER, unaffected), and class
-- groups are never self-joinable.

alter table public.clubs add column if not exists class_level text;
create unique index if not exists clubs_one_group_per_class
  on public.clubs (institution_id, class_level) where class_level is not null;

drop policy if exists club_members_insert_self on public.club_members;
create policy club_members_insert_self on public.club_members
  for insert with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.clubs c
      where c.id = club_members.club_id
        and not c.requires_approval
        and c.class_level is null
    )
  );

create or replace function public.create_class_group(p_class_level text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me public.users%rowtype;
  v_club uuid;
begin
  select * into v_me from public.users where id = auth.uid();
  if v_me.id is null or v_me.institution_id is null then
    raise exception 'Your account isn''t linked to a school';
  end if;
  if coalesce(p_class_level, '') = '' then
    raise exception 'Choose a class';
  end if;
  -- coalesce: class_master_of_class is NULL for ordinary teachers, and
  -- NOT (NULL OR false) is NULL -- which IF treats as "don't raise".
  if not (coalesce(v_me.class_master_of_class = p_class_level, false)
          or public.role_level(v_me.role) >= public.role_level('school_admin')) then
    raise exception 'Only the class master of % (or a school admin) can create its group', p_class_level
      using errcode = '42501';
  end if;

  select id into v_club from public.clubs
    where institution_id = v_me.institution_id and class_level = p_class_level;

  if v_club is null then
    insert into public.clubs (name, emoji, description, moderator_id, moderator_name, category,
                              institution_id, requires_approval, class_level, member_count)
    values (p_class_level || ' · Class group', '🏫',
            'Official group for ' || p_class_level || '. Announcements and questions for the whole class.',
            v_me.id, v_me.name, 'Class', v_me.institution_id, true, p_class_level, 0)
    returning id into v_club;
    insert into public.club_members (club_id, user_id, name, photo_url, role)
    values (v_club, v_me.id, v_me.name, v_me.photo_url, 'admin')
    on conflict do nothing;
  end if;

  perform public.sync_class_group_members(v_club);
  return v_club;
end;
$$;

-- Adds every current student of the class who isn't a member yet (new
-- arrivals after the group was created). Callable by the group's
-- moderator / staff; members removed by the class master stay removed
-- until the next explicit sync.
create or replace function public.sync_class_group_members(p_club_id uuid)
returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_club public.clubs%rowtype;
  v_added integer;
begin
  select * into v_club from public.clubs where id = p_club_id;
  if v_club.id is null or v_club.class_level is null then
    raise exception 'Not a class group';
  end if;
  if auth.uid() is not null and not (
       coalesce(v_club.moderator_id = auth.uid(), false)
       or coalesce(public.has_school_role(v_club.institution_id, 'school_admin'), false)
       or exists (select 1 from public.users u where u.id = auth.uid()
                  and u.institution_id = v_club.institution_id and u.class_master_of_class = v_club.class_level)) then
    raise exception 'Only the class master can update this group' using errcode = '42501';
  end if;

  insert into public.club_members (club_id, user_id, name, photo_url, role)
  select v_club.id, u.id, u.name, u.photo_url, 'member'
  from public.users u
  where u.institution_id = v_club.institution_id and u.class_level = v_club.class_level
    and u.role = 'student' and coalesce(u.school_role, '') <> 'parent'
  on conflict do nothing;
  get diagnostics v_added = row_count;

  update public.clubs set member_count = (select count(*) from public.club_members where club_id = v_club.id)
    where id = v_club.id;
  return v_added;
end;
$$;

revoke execute on function public.create_class_group(text) from anon;
revoke execute on function public.sync_class_group_members(uuid) from anon;
