-- 20260909160000_fix_club_join_request_approval.sql
-- User report: "In clubs you should have the ability to accept... you
-- can only decline, you cannot accept." Both bugs found:
--
-- 1. Data: three clubs ("bbbj", "xv", "Commonwealth Club Soa") predate
--    the clubs.moderator_id column/logic and have it NULL, even though
--    moderator_name correctly records who created them (all three: the
--    super_admin account "Nso Dylan"/id 25c28bdb-69e9-4b19-8f2c-31d97ff7ae5a,
--    "N.Dylan" being an older name variant of the same account). New
--    clubs (e.g. "Academia Chemists") already get moderator_id set
--    correctly by create_club_page.dart -- this is stale pre-existing
--    data, not an ongoing bug in club creation.
--
-- 2. Code: approve_club_join_request() and the
--    club_join_requests_update_moderator RLS policy (used by decline)
--    both ONLY ever recognized clubs.moderator_id as an authorized
--    approver/decliner. But club_members_page.dart's own UI shows the
--    Approve/Decline buttons to anyone with a PER-CLUB club_members.role
--    of 'admin' or 'moderator' (the "Set as Admin"/"Set as Moderator"
--    promotion system) -- so any promoted admin/moderator who wasn't
--    the original creator saw a working-looking button that always
--    silently failed with "Not authorized to approve this request."
--    (silently, because neither button's onPressed in the Dart client
--    awaited/surfaced the result either -- fixed client-side separately).
--    Broadened both to match the UI's actual authorization model.

update public.clubs
set moderator_id = '25c28bdb-69e9-4b19-8f2c-31d97ff7ae5a'
where moderator_id is null
  and moderator_name in ('Nso Dylan', 'N.Dylan');

create or replace function public.approve_club_join_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_req record;
begin
  select * into v_req from public.club_join_requests where id = p_request_id;
  if v_req is null then raise exception 'Request not found.'; end if;
  if not (
    exists (select 1 from public.clubs c where c.id = v_req.club_id and c.moderator_id = auth.uid())
    or exists (select 1 from public.club_members cm where cm.club_id = v_req.club_id and cm.user_id = auth.uid() and cm.role in ('admin', 'moderator'))
    or public.has_min_role('school_admin'::user_role)
  ) then
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

drop policy if exists "club_join_requests_update_moderator" on public.club_join_requests;
create policy "club_join_requests_update_moderator" on public.club_join_requests
  for update
  using (
    exists (select 1 from public.clubs c where c.id = club_join_requests.club_id and c.moderator_id = auth.uid())
    or exists (select 1 from public.club_members cm where cm.club_id = club_join_requests.club_id and cm.user_id = auth.uid() and cm.role in ('admin', 'moderator'))
  )
  with check (
    exists (select 1 from public.clubs c where c.id = club_join_requests.club_id and c.moderator_id = auth.uid())
    or exists (select 1 from public.club_members cm where cm.club_id = club_join_requests.club_id and cm.user_id = auth.uid() and cm.role in ('admin', 'moderator'))
  );
