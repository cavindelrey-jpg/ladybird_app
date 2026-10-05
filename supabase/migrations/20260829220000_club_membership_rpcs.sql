-- ============================================================================
-- ClubRepository's join/leave/approve/remove operations were Firestore
-- batches (write club_members + adjust clubs.member_count atomically).
-- Same RPC pattern as the magazine engagement functions.
-- ============================================================================

create or replace function public.join_club(p_club_id uuid, p_name text, p_photo_url text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Must be signed in to join a club.'; end if;
  insert into public.club_members (club_id, user_id, name, photo_url, role)
    values (p_club_id, auth.uid(), p_name, p_photo_url, 'member')
    on conflict (club_id, user_id) do nothing;
  if found then
    update public.clubs set member_count = member_count + 1 where id = p_club_id;
  end if;
end;
$$;

create or replace function public.leave_club(p_club_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Must be signed in.'; end if;
  delete from public.club_members where club_id = p_club_id and user_id = auth.uid();
  if found then
    update public.clubs set member_count = greatest(0, member_count - 1) where id = p_club_id;
  end if;
end;
$$;

create or replace function public.approve_club_join_request(p_request_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_req record;
begin
  select * into v_req from public.club_join_requests where id = p_request_id;
  if v_req is null then raise exception 'Request not found.'; end if;
  if not (exists (select 1 from public.clubs c where c.id = v_req.club_id and c.moderator_id = auth.uid())
          or public.has_min_role('school_admin')) then
    raise exception 'Not authorized to approve this request.';
  end if;

  update public.club_join_requests set status = 'approved' where id = p_request_id;
  insert into public.club_members (club_id, user_id, name, photo_url, role)
    values (v_req.club_id, v_req.user_id, v_req.user_name, v_req.user_photo_url, 'member')
    on conflict (club_id, user_id) do nothing;
  if found then
    update public.clubs set member_count = member_count + 1 where id = v_req.club_id;
  end if;
end;
$$;

create or replace function public.remove_club_member(p_club_id uuid, p_user_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not (exists (select 1 from public.clubs c where c.id = p_club_id and c.moderator_id = auth.uid())
          or public.has_min_role('school_admin')
          or auth.uid() = p_user_id) then
    raise exception 'Not authorized to remove this member.';
  end if;
  delete from public.club_members where club_id = p_club_id and user_id = p_user_id;
  if found then
    update public.clubs set member_count = greatest(0, member_count - 1) where id = p_club_id;
  end if;
end;
$$;
