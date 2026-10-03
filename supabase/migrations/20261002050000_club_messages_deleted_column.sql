-- 20261002050000_club_messages_deleted_column.sql
-- ClubMessage.toSupabase() writes `deleted` and ClubRepository.
-- deleteMessage() soft-deletes by setting it, but no migration in any of
-- the three repos creates the column -- so on a repo-built environment
-- every club / class-group message insert was rejected by PostgREST
-- (unknown column) and the chat UI silently discarded the text.
-- Idempotent: a no-op where the column already exists.
alter table public.club_messages add column if not exists deleted boolean not null default false;

-- The inbox preview (clubs.last_message_*) was updated by the client
-- after each send, but clubs UPDATE is moderator-only -- so for every
-- ordinary member that step failed and the send was reported as failed
-- even though the message had been saved. Maintained server-side now.
create or replace function public.club_message_preview()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.clubs
     set last_message_text = left(new.body, 200),
         last_message_sender_id = new.sender_id,
         last_message_at = coalesce(new.sent_at, now())
   where id = new.club_id;
  return new;
end;
$$;

drop trigger if exists trg_club_message_preview on public.club_messages;
create trigger trg_club_message_preview
  after insert on public.club_messages
  for each row execute function public.club_message_preview();
