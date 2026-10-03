-- 20261002040000_direct_conversation_rpc.sql
-- QA pass 2026-10-02: no migration in any of the three repos gives
-- public.conversations an INSERT policy, and MessagingRepository.
-- getOrCreateConversation() inserts directly -- so on any environment
-- built from the repos, starting a NEW conversation always failed with
-- "Failed to open conversation". It also required a friendship, which
-- meant a teacher couldn't message a student about homework until the
-- student accepted a friend request.
--
-- One SECURITY DEFINER entry point instead of a broad INSERT policy:
-- finds the existing 1:1 conversation or creates it, and decides who may
-- message whom:
--   * friends (unchanged), or
--   * two members of the same school where at least one is staff
--     (lecturer or above, or a class master) -- teacher <-> student,
--     class master <-> student, staff <-> staff.
-- Student <-> student still needs a friendship.

create or replace function public.get_or_create_direct_conversation(p_other uuid)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me public.users%rowtype;
  v_other public.users%rowtype;
  v_id uuid;
  v_allowed boolean;
begin
  select * into v_me from public.users where id = auth.uid();
  select * into v_other from public.users where id = p_other;
  if v_me.id is null then raise exception 'Sign in to send messages'; end if;
  if v_other.id is null then raise exception 'That account no longer exists'; end if;
  if v_me.id = v_other.id then raise exception 'You can''t message yourself'; end if;

  v_allowed := exists (
      select 1 from public.friendships f
      where (f.user_a_id = v_me.id and f.user_b_id = v_other.id)
         or (f.user_a_id = v_other.id and f.user_b_id = v_me.id))
    or (v_me.institution_id is not null
        and v_me.institution_id = v_other.institution_id
        and (public.role_level(v_me.role) >= public.role_level('lecturer')
             or public.role_level(v_other.role) >= public.role_level('lecturer')
             or coalesce(v_me.class_master_of_class, '') <> ''
             or coalesce(v_other.class_master_of_class, '') <> ''));
  if not coalesce(v_allowed, false) then
    raise exception 'You need to be friends to message each other' using errcode = '42501';
  end if;

  select c.id into v_id from public.conversations c
   where c.participant_ids @> array[v_me.id, v_other.id]
     and cardinality(c.participant_ids) = 2
   limit 1;
  if v_id is not null then return v_id; end if;

  insert into public.conversations (participant_ids, participant_names, participant_photos, last_message_at)
  values (array[v_me.id, v_other.id],
          jsonb_build_object(v_me.id::text, v_me.name, v_other.id::text, v_other.name),
          jsonb_build_object(v_me.id::text, v_me.photo_url, v_other.id::text, v_other.photo_url),
          now())
  returning id into v_id;
  return v_id;
end;
$$;

revoke execute on function public.get_or_create_direct_conversation(uuid) from anon;
