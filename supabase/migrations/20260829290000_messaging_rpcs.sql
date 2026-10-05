-- ============================================================================
-- MessagingRepository's acceptRequest (2-table write: mark request
-- accepted + create friendship) and sendMessage (2-table write: insert
-- message + update conversation preview) were Firestore batches.
-- ============================================================================

create or replace function public.accept_friend_request(p_request_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_req record;
  v_a uuid;
  v_b uuid;
begin
  select * into v_req from public.friend_requests where id = p_request_id;
  if v_req is null then raise exception 'Request not found.'; end if;
  if auth.uid() is null or auth.uid() <> v_req.to_user_id then
    raise exception 'Not authorized to accept this request.';
  end if;

  update public.friend_requests set status = 'accepted' where id = p_request_id;

  if v_req.from_user_id < v_req.to_user_id then
    v_a := v_req.from_user_id; v_b := v_req.to_user_id;
  else
    v_a := v_req.to_user_id; v_b := v_req.from_user_id;
  end if;

  insert into public.friendships (id, user_a_id, user_b_id)
    values (v_a::text || '_' || v_b::text, v_a, v_b)
    on conflict (id) do nothing;
end;
$$;

create or replace function public.send_chat_message(
  p_conversation_id uuid, p_sender_id uuid, p_sender_name text, p_body text,
  p_image_url text, p_video_url text, p_file_url text, p_file_name text,
  p_content_ref jsonb, p_preview text
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  if auth.uid() is null or auth.uid() <> p_sender_id then
    raise exception 'Must be signed in as the sender.';
  end if;
  insert into public.direct_messages (
    conversation_id, sender_id, sender_name, body, image_url, video_url,
    file_url, file_name, content_ref, read_by
  ) values (
    p_conversation_id, p_sender_id, p_sender_name, p_body, p_image_url, p_video_url,
    p_file_url, p_file_name, p_content_ref, array[p_sender_id]
  ) returning id into v_id;

  update public.conversations set
    last_message_text = p_preview, last_message_sender_id = p_sender_id, last_message_at = now()
    where id = p_conversation_id;

  return v_id;
end;
$$;

create or replace function public.mark_conversation_read(p_conversation_id uuid, p_user_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'Not authorized.';
  end if;
  update public.direct_messages
    set read_by = array_append(read_by, p_user_id)
    where conversation_id = p_conversation_id
      and not (read_by @> array[p_user_id]);
end;
$$;

alter publication supabase_realtime add table public.friend_requests;
alter publication supabase_realtime add table public.friendships;
alter publication supabase_realtime add table public.conversations;
alter publication supabase_realtime add table public.direct_messages;
