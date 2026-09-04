-- 20260904000002_fix_announcement_notify_school_id.sql
-- notify_school_on_announcement() (20260901032000) was written against
-- `u.school_id`, a column that has never existed on public.users -- it's
-- `institution_id` (the same mistake 20260903150000 fixed on
-- school_marks/school_timetable_slots the very next day, but this
-- trigger predates that fix and was never patched). Since the trigger
-- runs AFTER INSERT on public.announcements in the same transaction,
-- every school-scoped announcement insert (institution_id is not null)
-- has been raising "column u.school_id does not exist" and rolling back
-- the whole announcement -- i.e. spec item 9A ("every announcement
-- automatically generates a notification") has likely been silently
-- broken since 20260901, not merely unimplemented.
--
-- Re-creating the function body only; the trigger itself doesn't need
-- to be re-created.

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
    where u.institution_id = new.institution_id
      and u.id is distinct from new.author_id;
  end if;
  return new;
end;
$$;
