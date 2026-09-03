-- 20260903171000_daily_program_cron.sql
-- The automated "Tomorrow's Program" aggregator (spec items 4, 5, 9, 10):
-- teachers/admins enter homework/timetable/calendar data, the system
-- compiles it, nobody manually composes a notification. Delivered as an
-- in-app notification (existing notifications table + Realtime feed --
-- this project has no push/FCM infra yet), scheduled daily at 07:00 WAT
-- (Africa/Douala is UTC+1, no DST, so 06:00 UTC is always 07:00 WAT).
--
-- "Tomorrow" is computed in Africa/Douala local time, not the database
-- server's own timezone, so the aggregation always describes the correct
-- calendar day for a Cameroonian school regardless of where Postgres
-- itself is hosted.
--
-- A student with nothing to report tomorrow (no timetable row, no
-- homework due, no calendar event) gets no notification at all --
-- honest silence over an empty "Tomorrow's Program" card.

create extension if not exists pg_cron;

create or replace function public.generate_daily_program()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tomorrow date := ((now() at time zone 'Africa/Douala')::date) + 1;
  v_dow smallint := extract(isodow from v_tomorrow);
  v_label text := to_char(v_tomorrow, 'FMDay, FMMonth FMDD');
  v_student record;
  v_timetable text;
  v_homework text;
  v_events text;
  v_body text;
begin
  for v_student in
    select id, institution_id, class_level
    from public.users
    where role = 'student'
      and institution_id is not null
      and class_level is not null
      and class_level <> ''
  loop
    select string_agg(
             s.start_time || '-' || s.end_time || ' ' || s.subject ||
               case when coalesce(s.room, '') <> '' then ' (Room ' || s.room || ')' else '' end,
             e'\n' order by s.start_time
           )
      into v_timetable
      from public.school_timetable_slots s
      where s.school_id = v_student.institution_id
        and s.class_level = v_student.class_level
        and s.day_of_week = v_dow;

    select string_agg(h.subject || ': ' || h.title, e'\n' order by h.subject)
      into v_homework
      from public.homework h
      where h.school_id = v_student.institution_id
        and h.class_level = v_student.class_level
        and h.due_at::date = v_tomorrow;

    select string_agg(
             c.title || case when coalesce(c.location, '') <> '' then ' - ' || c.location else '' end,
             e'\n'
           )
      into v_events
      from public.school_calendar_events c
      where c.school_id = v_student.institution_id
        and v_tomorrow between c.start_date and c.end_date
        and (c.affected_classes = '{}' or v_student.class_level = any (c.affected_classes));

    if v_timetable is null and v_homework is null and v_events is null then
      continue;
    end if;

    v_body := 'Here''s what you need to know for ' || v_label || '.';
    if v_events is not null then
      v_body := v_body || e'\n\nSchool activity:\n' || v_events;
    end if;
    if v_timetable is not null then
      v_body := v_body || e'\n\nTomorrow''s timetable:\n' || v_timetable;
    end if;
    if v_homework is not null then
      v_body := v_body || e'\n\nHomework due:\n' || v_homework;
    end if;

    insert into public.notifications (user_id, type, title, body, read)
    values (v_student.id, 'daily_program', 'Tomorrow''s Program', v_body, false);
  end loop;
end;
$$;

do $$
begin
  perform cron.unschedule(jobid) from cron.job where jobname = 'daily-program';
end;
$$;

select cron.schedule('daily-program', '0 6 * * *', $$select public.generate_daily_program();$$);
