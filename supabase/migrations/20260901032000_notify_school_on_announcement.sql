-- 20260901032000_notify_school_on_announcement.sql
-- Posting a school announcement (AnnouncementRepository.post(), gated to
-- AppUser.canPostAnnouncement client-side) only ever inserted a row into
-- `announcements` -- students only ever saw it if they happened to open
-- the Announcements page themselves. Nothing populated the real,
-- already-working per-user `notifications` table (the one the bell icon
-- / NotificationsPage actually reads), so a posted announcement never
-- generated a real notification for anyone.
--
-- A trigger rather than a client-side fan-out loop: inserting one
-- notifications row per student from the app would mean N round trips
-- for a school with hundreds of students, and a half-finished fan-out on
-- a dropped connection would silently under-notify. This is atomic with
-- the announcement insert itself and runs server-side in one statement.
--
-- Scoped to school announcements only (institution_id is not null) --
-- the unscoped/global announcement feed (see models/announcement.dart's
-- own file comment: "the default unscoped collection is what
-- independent/guest accounts read from") has no bounded, sensible
-- audience to fan out to the same way.

create or replace function public.notify_school_on_announcement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.institution_id is not null then
    insert into public.notifications (user_id, type, title, body, deep_link_id, read)
    select u.id, 'announcement', new.title, new.body, new.id, false
    from public.users u
    where u.school_id = new.institution_id
      and u.id is distinct from new.author_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_school_on_announcement on public.announcements;
create trigger trg_notify_school_on_announcement
  after insert on public.announcements
  for each row execute function public.notify_school_on_announcement();
