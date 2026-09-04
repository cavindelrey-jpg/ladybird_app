-- 20260904000004_notify_on_direct_message.sql
-- Spec item 9B: a direct message must generate a real notification for
-- the recipient, not just update the conversation's unread counter that
-- only the Messages tab itself reads.
--
-- direct_messages/conversations aren't defined in this repo's own
-- migrations (base schema lives in the sibling greenhills_app repo this
-- app forked from -- shared Supabase project, see docs/AUTOPILOT_LOG.md).
-- Column names below are NOT guessed: every one is independently
-- confirmed by both directions of lib/models/messaging.dart's Supabase
-- mapping (ChatMessage.fromSupabase/toSupabase for direct_messages;
-- Conversation.fromSupabase/toSupabase for conversations,
-- participant_ids in particular) -- both read and write agree on them,
-- so this trigger only reads columns the app itself already depends on.
--
-- participant_ids' underlying Postgres type isn't independently
-- confirmed (the Dart client's .contains()/List<String>.from() calls
-- work identically against a native array or a jsonb array column) --
-- to stay correct either way, this converts it with to_jsonb() (a no-op
-- on an already-jsonb column, and a clean array-to-jsonb-array
-- conversion on a native array column) before iterating, rather than
-- assuming one representation and risking the exact "silently wrong
-- instead of erroring" class of bug 20260903150000 had to fix.

create or replace function public.notify_on_direct_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recipient text;
  v_body text;
begin
  if coalesce(new.deleted, false) then
    return new;
  end if;

  v_body := case
    when coalesce(new.body, '') <> '' then new.body
    when new.image_url is not null then '📷 Photo'
    when new.video_url is not null then '🎥 Video'
    when new.file_url is not null then '📎 ' || coalesce(new.file_name, 'File')
    when new.shared_type is not null then coalesce(new.shared_title, 'Shared content')
    else 'Sent you a message'
  end;

  for v_recipient in
    select p from (
      select jsonb_array_elements_text(to_jsonb(c.participant_ids)) as p
      from public.conversations c
      where c.id = new.conversation_id
    ) participants
    where p is distinct from new.sender_id::text
  loop
    insert into public.notifications (user_id, type, title, body, deep_link_id, read)
    values (v_recipient::uuid, 'message', coalesce(new.sender_name, 'New message'), v_body, new.conversation_id, false);
  end loop;

  return new;
end;
$$;

drop trigger if exists trg_notify_on_direct_message on public.direct_messages;
create trigger trg_notify_on_direct_message
  after insert on public.direct_messages
  for each row execute function public.notify_on_direct_message();
