-- ============================================================================
-- greenhills_app/ladybird_app additions on top of the shared messaging
-- RPCs (20260829290000_messaging_rpcs.sql):
--   - send_chat_message_v2: a separate function (not a signature change
--     to send_chat_message, which academia-cameroon still calls as-is)
--     for the flat shared_* attachment columns instead of a nested
--     content_ref jsonb, plus incrementing the recipient's unread_count
--     — a real bug fix (unread_count was declared and read in the UI but
--     never actually written by either app's Firestore version).
--   - mark_conversation_read extended to also zero the caller's own
--     unread_count entry — safe for academia-cameroon too, since nothing
--     there increments unread_count in the first place (stays 0 either
--     way).
--   - ping_conversation_active / toggle_conversation_pin: real per-
--     conversation presence and a per-user pin preference, both needing
--     an atomic jsonb/array merge a plain client-side .update() can't do
--     without clobbering other participants' entries.
-- ============================================================================

create or replace function public.send_chat_message_v2(
  p_conversation_id uuid, p_sender_id uuid, p_sender_name text, p_body text,
  p_image_url text, p_video_url text, p_file_url text, p_file_name text,
  p_shared_type text, p_shared_id text, p_shared_title text, p_shared_subtitle text, p_shared_thumbnail_url text,
  p_preview text, p_recipient_id uuid default null
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
    file_url, file_name, shared_type, shared_id, shared_title, shared_subtitle, shared_thumbnail_url,
    read_by
  ) values (
    p_conversation_id, p_sender_id, p_sender_name, p_body, p_image_url, p_video_url,
    p_file_url, p_file_name, p_shared_type, p_shared_id, p_shared_title, p_shared_subtitle, p_shared_thumbnail_url,
    array[p_sender_id]
  ) returning id into v_id;

  update public.conversations set
    last_message_text = p_preview, last_message_sender_id = p_sender_id, last_message_at = now(),
    unread_count = case when p_recipient_id is not null
      then unread_count || jsonb_build_object(
        p_recipient_id::text, coalesce((unread_count ->> p_recipient_id::text)::int, 0) + 1
      )
      else unread_count
    end
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
  update public.conversations
    set unread_count = unread_count || jsonb_build_object(p_user_id::text, 0)
    where id = p_conversation_id;
end;
$$;

create or replace function public.ping_conversation_active(p_conversation_id uuid, p_user_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.conversations
    set active_at = active_at || jsonb_build_object(p_user_id::text, now())
    where id = p_conversation_id;
end;
$$;

create or replace function public.toggle_conversation_pin(p_conversation_id uuid, p_user_id uuid, p_pinned boolean)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'Not authorized.';
  end if;
  if p_pinned then
    update public.conversations set pinned_by = array_append(pinned_by, p_user_id)
      where id = p_conversation_id and not (pinned_by @> array[p_user_id]);
  else
    update public.conversations set pinned_by = array_remove(pinned_by, p_user_id)
      where id = p_conversation_id;
  end if;
end;
$$;
