-- 20261002010000_scheduled_notifications_hardening.sql
-- QA pass 2026-10-02: the two scheduled generators had these problems,
-- reproduced on a local replica by simulating three consecutive days:
--
--  * Neither was idempotent -- a retried/duplicated cron run (or a manual
--    run) delivered every notification twice.
--  * Recommendations all used type 'recommendation' with a bare id in
--    deep_link_id, so the app couldn't tell a course from a library item
--    from a quiz; tapping one did nothing.
--  * Unpublished (draft) courses and quizzes could be recommended.
--  * Parent accounts (role 'student', school_role 'parent') got student
--    recommendations, while getting NO daily programme for their child.
--  * Teachers got no "tomorrow" programme at all.
--  * Neither honoured notification preferences; there was no switch for
--    either one.
--  * No way to exercise the schedule deterministically: both read now().
--
-- Both functions now take p_now (default now()). cron calls them with no
-- argument, so production behaviour is unchanged; tests pass a fixed
-- instant to simulate "7 PM on day N". deep_link_id is now typed:
--   program:YYYY-MM-DD | course:<id> | content:<id> | test:<id> | challenge:YYYY-MM-DD
-- and doubles as the idempotency key (one per user per type per day).

alter table public.notification_preferences
  add column if not exists daily_program boolean not null default true,
  add column if not exists recommendations boolean not null default true;

create or replace function public._notify_once(
  p_user uuid, p_type notification_type, p_title text, p_body text, p_link text, p_day date
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if exists (
    select 1 from public.notifications n
    where n.user_id = p_user and n.type = p_type
      and (n.deep_link_id = p_link
           or (p_type = 'recommendation'
               and split_part(n.deep_link_id, ':', 1) = split_part(p_link, ':', 1)
               and (n.created_at at time zone 'Africa/Douala')::date = p_day))
  ) then
    return;
  end if;
  insert into public.notifications (user_id, type, title, body, deep_link_id, read)
  values (p_user, p_type, p_title, p_body, p_link, false);
end;
$$;

create or replace function public._wants(p_user uuid, p_kind text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((
    select case p_kind when 'daily_program' then p.daily_program else p.recommendations end
    from public.notification_preferences p where p.user_id = p_user
  ), true);
$$;

drop function if exists public.generate_daily_program();
create or replace function public.generate_daily_program(p_now timestamptz default now())
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tomorrow date := ((p_now at time zone 'Africa/Douala')::date) + 1;
  v_dow smallint := extract(isodow from v_tomorrow);
  v_label text := to_char(v_tomorrow, 'FMDay, FMDD FMMonth');
  v_link text := 'program:' || to_char(v_tomorrow, 'YYYY-MM-DD');
  v_class record;
  v_timetable text;
  v_homework text;
  v_events text;
  v_body text;
  v_rec record;
  v_count integer := 0;
begin
  -- One body per (school, class), shared by its students and their parents.
  for v_class in
    select distinct institution_id as school_id, class_level
    from public.users
    where role = 'student' and coalesce(school_role, '') <> 'parent'
      and institution_id is not null and coalesce(class_level, '') <> ''
  loop
    select string_agg(
             s.start_time || '–' || s.end_time || '  ' || s.subject ||
               case when coalesce(s.teacher_name, '') <> '' then ' · ' || s.teacher_name else '' end ||
               case when coalesce(s.room, '') <> '' then ' (Room ' || s.room || ')' else '' end,
             e'\n' order by s.start_time)
      into v_timetable
      from public.school_timetable_slots s
      where s.school_id = v_class.school_id and s.class_level = v_class.class_level
        and s.day_of_week = v_dow;

    select string_agg(h.subject || ': ' || h.title, e'\n' order by h.subject)
      into v_homework
      from public.homework h
      where h.school_id = v_class.school_id and h.class_level = v_class.class_level
        and (h.due_at at time zone 'Africa/Douala')::date = v_tomorrow;

    select string_agg(c.title || case when coalesce(c.location, '') <> '' then ' – ' || c.location else '' end, e'\n')
      into v_events
      from public.school_calendar_events c
      where c.school_id = v_class.school_id
        and v_tomorrow between c.start_date and c.end_date
        and (c.affected_classes = '{}' or v_class.class_level = any (c.affected_classes));

    -- Honest silence over an empty card.
    continue when v_timetable is null and v_homework is null and v_events is null;

    v_body := '';
    if v_events is not null then v_body := v_body || e'School activity:\n' || v_events || e'\n\n'; end if;
    if v_timetable is not null then v_body := v_body || e'Classes:\n' || v_timetable || e'\n\n'; end if;
    if v_homework is not null then v_body := v_body || e'Homework due:\n' || v_homework || e'\n\n'; end if;
    v_body := rtrim(v_body, e'\n');

    for v_rec in
      select u.id, null::text as child_name
      from public.users u
      where u.role = 'student' and coalesce(u.school_role, '') <> 'parent'
        and u.institution_id = v_class.school_id and u.class_level = v_class.class_level
      union all
      select pl.parent_id, su.name
      from public.academia_parent_student_links pl
      join public.users su on su.id = pl.student_id
      where su.institution_id = v_class.school_id and su.class_level = v_class.class_level
    loop
      continue when not public._wants(v_rec.id, 'daily_program');
      perform public._notify_once(
        v_rec.id, 'daily_program',
        case when v_rec.child_name is null then 'Tomorrow · ' || v_label
             else v_rec.child_name || ' · ' || v_label end,
        v_body,
        v_link || case when v_rec.child_name is null then '' else ':' || v_class.class_level end,
        v_tomorrow);
      v_count := v_count + 1;
    end loop;
  end loop;

  -- Teachers: their own periods tomorrow (slots carry teacher_name).
  for v_rec in
    select u.id, string_agg(
             s.start_time || '–' || s.end_time || '  ' ||
             s.subject || ' · ' || s.class_level ||
             case when coalesce(s.room, '') <> '' then ' (Room ' || s.room || ')' else '' end,
             e'\n' order by s.start_time) as periods
    from public.users u
    join public.school_timetable_slots s
      on s.school_id = u.institution_id and s.day_of_week = v_dow
     and lower(trim(s.teacher_name)) = lower(trim(u.name))
    where u.role in ('lecturer', 'department_admin', 'school_admin')
    group by u.id
  loop
    continue when not public._wants(v_rec.id, 'daily_program');
    perform public._notify_once(v_rec.id, 'daily_program', 'Your classes · ' || v_label,
                                e'Classes:\n' || v_rec.periods, v_link, v_tomorrow);
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

drop function if exists public.generate_recommendation_notifications();
create or replace function public.generate_recommendation_notifications(p_now timestamptz default now())
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today date := (p_now at time zone 'Africa/Douala')::date;
  v_student record;
  v_pick record;
  v_count integer := 0;
begin
  for v_student in
    select u.id, u.favorite_subjects, u.institution_id
    from public.users u
    where u.role = 'student' and coalesce(u.school_role, '') <> 'parent'
      and coalesce(u.status::text, 'active') = 'active'
  loop
    continue when not public._wants(v_student.id, 'recommendations');

    -- Daily Challenge reminder, unless today's is already done.
    if not exists (
      select 1 from public.daily_learning_streaks d
      where d.user_id = v_student.id
        and (d.last_completed_date at time zone 'Africa/Douala')::date = v_today
    ) then
      perform public._notify_once(v_student.id, 'recommendation', 'Today''s Daily Challenge',
        'A new challenge is waiting — keep your streak alive and earn bonus XP.',
        'challenge:' || to_char(v_today, 'YYYY-MM-DD'), v_today);
      v_count := v_count + 1;
    end if;

    select c.id, c.title into v_pick
      from public.courses c
      where c.published
        and (c.institution_id is null or c.institution_id = v_student.institution_id)
        and not exists (select 1 from public.course_recent_views v where v.course_id = c.id and v.user_id = v_student.id)
      order by (v_student.favorite_subjects is not null and c.subject = any(v_student.favorite_subjects)) desc, random()
      limit 1;
    if v_pick.id is not null then
      perform public._notify_once(v_student.id, 'recommendation', 'A course for you',
        'Check out "' || v_pick.title || '" in Courses.', 'course:' || v_pick.id, v_today);
      v_count := v_count + 1;
    end if;
    v_pick := null;

    select ac.id, ac.title into v_pick
      from public.academic_content ac
      where coalesce(ac.file_url, '') <> ''
        and (ac.institution_id is null or ac.institution_id = v_student.institution_id)
        and not exists (select 1 from public.content_recent_views v where v.content_id = ac.id and v.user_id = v_student.id)
      order by (v_student.favorite_subjects is not null and ac.subject = any(v_student.favorite_subjects)) desc, random()
      limit 1;
    if v_pick.id is not null then
      perform public._notify_once(v_student.id, 'recommendation', 'Book of the day',
        '"' || v_pick.title || '" looks like a good read for you.', 'content:' || v_pick.id, v_today);
      v_count := v_count + 1;
    end if;
    v_pick := null;
  end loop;
  return v_count;
end;
$$;

-- Re-point the cron jobs at the new signatures (same times as before:
-- 18:00 UTC = 19:00 WAT for tomorrow's programme, 08:00 UTC = 09:00 WAT
-- for recommendations). This also settles the 06:00-vs-18:00 drift
-- between this repo's 20260903171000 and greenhills_app's reschedule.
do $$
begin
  perform cron.unschedule(jobid) from cron.job where jobname in ('daily-program', 'recommendation-notifications');
end;
$$;
select cron.schedule('daily-program', '0 18 * * *', $$select public.generate_daily_program();$$);
select cron.schedule('recommendation-notifications', '0 8 * * *', $$select public.generate_recommendation_notifications();$$);

revoke execute on function public.generate_daily_program(timestamptz) from public, anon, authenticated;
revoke execute on function public.generate_recommendation_notifications(timestamptz) from public, anon, authenticated;
revoke execute on function public._notify_once(uuid, notification_type, text, text, text, date) from public, anon, authenticated;

-- ── Magazine notifications, server-side ─────────────────────────────────
-- The app used to insert these from the client for OTHER users (comment
-- -> article author, publish -> every follower). notifications has no
-- INSERT policy (correctly -- otherwise anyone could spam anyone), so
-- every one of those inserts was rejected and silently swallowed: authors
-- never heard about comments, followers never heard about new articles.
create or replace function public.notify_on_article_comment()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_article record;
  v_parent_author uuid;
begin
  select id, author_id, title into v_article from public.magazine_articles where id = new.article_id;
  if v_article.id is null then return new; end if;

  if new.parent_comment_id is not null then
    select author_id into v_parent_author from public.article_comments where id = new.parent_comment_id;
    if v_parent_author is not null and v_parent_author <> new.author_id
       and coalesce((select replies from public.notification_preferences where user_id = v_parent_author), true) then
      insert into public.notifications (user_id, type, title, body, deep_link_id)
      values (v_parent_author, 'reply', new.author_name || ' replied to you',
              left(new.body, 140), 'article:' || v_article.id);
    end if;
  end if;

  if v_article.author_id <> new.author_id
     and v_article.author_id is distinct from v_parent_author
     and coalesce((select comments from public.notification_preferences where user_id = v_article.author_id), true) then
    insert into public.notifications (user_id, type, title, body, deep_link_id)
    values (v_article.author_id, 'comment', 'New comment on "' || v_article.title || '"',
            new.author_name || ': ' || left(new.body, 140), 'article:' || v_article.id);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_on_article_comment on public.article_comments;
create trigger trg_notify_on_article_comment
  after insert on public.article_comments
  for each row execute function public.notify_on_article_comment();

create or replace function public.notify_on_article_published()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_author text;
begin
  if not new.published or (tg_op = 'UPDATE' and old.published) then
    return new;
  end if;
  select name into v_author from public.users where id = new.author_id;
  insert into public.notifications (user_id, type, title, body, deep_link_id)
  select f.follower_id, 'article_published',
         coalesce(v_author, 'Someone you follow') || ' published a new article',
         new.title, 'article:' || new.id
  from public.follows f
  where f.followed_id = new.author_id
    and coalesce((select p.new_articles from public.notification_preferences p where p.user_id = f.follower_id), true)
    and not exists (select 1 from public.notifications n
                    where n.user_id = f.follower_id and n.deep_link_id = 'article:' || new.id
                      and n.type = 'article_published');
  return new;
end;
$$;

drop trigger if exists trg_notify_on_article_published on public.magazine_articles;
create trigger trg_notify_on_article_published
  after insert or update of published on public.magazine_articles
  for each row execute function public.notify_on_article_published();
