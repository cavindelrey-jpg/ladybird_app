-- ============================================================================
-- Fixes: "a club admin can decline a join request but not approve it."
--
-- Root cause: club_join_requests' RLS policies and the
-- approve_club_join_request/remove_club_member RPCs (20260829120000,
-- 20260829220000) only ever checked the legacy single-owner
-- clubs.moderator_id column. The clubs remake (20260829450000) introduced
-- a real multi-admin model — club_members.role in ('admin','moderator'),
-- exposed via public.is_club_staff() and already used correctly by
-- club_posts/club_discussions RLS — and the UI (club_members_page.dart's
-- canApprove, the "promote to Admin" action) already lets any club admin
-- act as staff. The join-request path and member-removal path never got
-- the same update.
--
-- Effect of the bug: a promoted co-admin (role='admin' in club_members,
-- but not the club's original moderator_id) hits two different failure
-- shapes for what should be one permission:
--   - Decline: a plain client-side UPDATE gated only by RLS. Blocked rows
--     are just filtered out, not errored — Postgrest returns success with
--     zero rows changed, so the app reports success but nothing happened.
--   - Approve: an RPC that explicitly `raise exception`s when unauthorized
--     — a visible, loud failure.
-- Net effect looked exactly like "decline works, approve doesn't."
-- Same root cause also blocks a co-admin from removing a member.
-- ============================================================================

-- club_join_requests: co-admins/moderators can see and act on requests for
-- their own club, not just the original creator.
drop policy if exists "club_join_requests_select_own_or_moderator" on public.club_join_requests;
create policy "club_join_requests_select_own_or_staff" on public.club_join_requests for select
  using (
    user_id = auth.uid()
    or public.is_club_staff(club_id)
    or public.has_min_role('school_admin')
  );

drop policy if exists "club_join_requests_update_moderator" on public.club_join_requests;
create policy "club_join_requests_update_staff" on public.club_join_requests for update
  using (public.is_club_staff(club_id) or public.has_min_role('school_admin'))
  with check (public.is_club_staff(club_id) or public.has_min_role('school_admin'));

-- club_members: co-admins/moderators can remove a member, not just the
-- original creator.
drop policy if exists "club_members_delete_self_or_moderator" on public.club_members;
create policy "club_members_delete_self_or_staff" on public.club_members for delete
  using (
    user_id = auth.uid()
    or public.is_club_staff(club_id)
    or public.has_min_role('school_admin')
  );

create or replace function public.approve_club_join_request(p_request_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_req record;
begin
  select * into v_req from public.club_join_requests where id = p_request_id;
  if v_req is null then raise exception 'Request not found.'; end if;
  if not (public.is_club_staff(v_req.club_id) or public.has_min_role('school_admin')) then
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
  if not (public.is_club_staff(p_club_id)
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
