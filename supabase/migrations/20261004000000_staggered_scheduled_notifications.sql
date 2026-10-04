-- 20261004000000_staggered_scheduled_notifications.sql
-- Stagger scheduled notifications throughout the day to avoid batching:
--   1. Morning: ~7:15 AM WAT (06:15 UTC) -> Daily Challenge reminder
--   2. Late Morning: ~11:30 AM WAT (10:30 UTC) -> Library / Book of the day
--   3. Afternoon: ~3:00 PM WAT (14:00 UTC) -> Course recommendation
--   4. Evening: ~6:30 PM WAT (17:30 UTC) -> Tomorrow's Programme
--
-- Each notification function is independently runnable and schedules distinct
-- timestamps across the day, ensuring notifications do not arrive in one single batch.

-- Update _notify_once to support an optional explicit timestamp (defaulting to now())
create or replace function public._notify_once(
  p_user uuid,
  p_type notification_type,
  p_title text,
  p_body text,
  p_link text,
  p_day date,
  p_created_at timestamptz default now()
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
  insert into public.notifications (user_id, type, title, body, deep_link_id, read, created_at)
  values (p_user, p_type, p_title, p_body, p_link, false, coalesce(p_created_at, now()));
end;
$$;

-- 1. Morning Challenge (07:15 WAT / 06:15 UTC)
create or replace function public.generate_morning_challenge_notification(p_now timestamptz default now())
returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_today date := (p_now at time zone 'Africa/Douala')::date;
  v_student record;
  v_count integer := 0;
  v_timestamp timestamptz := p_now;
begin
  for v_student in
    select u.id
    from public.users u
    where u.role = 'student' and coalesce(u.school_role, '') <> 'parent'
      and coalesce(u.status::text, 'active') = 'active'
  loop
    continue when not public._wants(v_student.id, 'recommendations');

    if not exists (
      select 1 from public.daily_learning_streaks d
      where d.user_id = v_student.id
        and (d.last_completed_date at time zone 'Africa/Douala')::date = v_today
    ) then
      perform public._notify_once(
        v_student.id,
        'recommendation',
        'Today''s Daily Challenge',
        'A new challenge is waiting — keep your streak alive and earn bonus XP.',
        'challenge:' || to_char(v_today, 'YYYY-MM-DD'),
        v_today,
        v_timestamp
      );
      v_count := v_count + 1;
    end if;
  end loop;
  return v_count;
end;
$$;

-- 2. Late Morning Library / Book (11:30 WAT / 10:30 UTC)
create or replace function public.generate_late_morning_library_notification(p_now timestamptz default now())
returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_today date := (p_now at time zone 'Africa/Douala')::date;
  v_student record;
  v_pick record;
  v_count integer := 0;
  v_timestamp timestamptz := p_now;
begin
  for v_student in
    select u.id, u.favorite_subjects, u.institution_id
    from public.users u
    where u.role = 'student' and coalesce(u.school_role, '') <> 'parent'
      and coalesce(u.status::text, 'active') = 'active'
  loop
    continue when not public._wants(v_student.id, 'recommendations');

    select ac.id, ac.title into v_pick
      from public.academic_content ac
      where coalesce(ac.file_url, '') <> ''
        and (ac.institution_id is null or ac.institution_id = v_student.institution_id)
        and not exists (select 1 from public.content_recent_views v where v.content_id = ac.id and v.user_id = v_student.id)
      order by (v_student.favorite_subjects is not null and ac.subject = any(v_student.favorite_subjects)) desc, random()
      limit 1;

    if v_pick.id is not null then
      perform public._notify_once(
        v_student.id,
        'recommendation',
        'Book of the day',
        '"' || v_pick.title || '" looks like a good read for you.',
        'content:' || v_pick.id,
        v_today,
        v_timestamp
      );
      v_count := v_count + 1;
    end if;
    v_pick := null;
  end loop;
  return v_count;
end;
$$;

-- 3. Afternoon Course (15:00 WAT / 14:00 UTC)
create or replace function public.generate_afternoon_course_notification(p_now timestamptz default now())
returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_today date := (p_now at time zone 'Africa/Douala')::date;
  v_student record;
  v_pick record;
  v_count integer := 0;
  v_timestamp timestamptz := p_now;
begin
  for v_student in
    select u.id, u.favorite_subjects, u.institution_id
    from public.users u
    where u.role = 'student' and coalesce(u.school_role, '') <> 'parent'
      and coalesce(u.status::text, 'active') = 'active'
  loop
    continue when not public._wants(v_student.id, 'recommendations');

    select c.id, c.title into v_pick
      from public.courses c
      where c.published
        and (c.institution_id is null or c.institution_id = v_student.institution_id)
        and not exists (select 1 from public.course_recent_views v where v.course_id = c.id and v.user_id = v_student.id)
      order by (v_student.favorite_subjects is not null and c.subject = any(v_student.favorite_subjects)) desc, random()
      limit 1;

    if v_pick.id is not null then
      perform public._notify_once(
        v_student.id,
        'recommendation',
        'A course for you',
        'Check out "' || v_pick.title || '" in Courses.',
        'course:' || v_pick.id,
        v_today,
        v_timestamp
      );
      v_count := v_count + 1;
    end if;
    v_pick := null;
  end loop;
  return v_count;
end;
$$;

-- Maintain generate_recommendation_notifications as an umbrella generator
-- that staggers timestamps across the day if invoked manually or in tests.
create or replace function public.generate_recommendation_notifications(p_now timestamptz default now())
returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_day date := (p_now at time zone 'Africa/Douala')::date;
  v_t_morning timestamptz := ((v_day::text || ' 07:15:00')::timestamp at time zone 'Africa/Douala');
  v_t_midday  timestamptz := ((v_day::text || ' 11:30:00')::timestamp at time zone 'Africa/Douala');
  v_t_afternoon timestamptz := ((v_day::text || ' 15:00:00')::timestamp at time zone 'Africa/Douala');
  v_count integer := 0;
begin
  v_count := v_count + public.generate_morning_challenge_notification(v_t_morning);
  v_count := v_count + public.generate_late_morning_library_notification(v_t_midday);
  v_count := v_count + public.generate_afternoon_course_notification(v_t_afternoon);
  return v_count;
end;
$$;

-- Schedule the staggered cron jobs (time in UTC)
do $$
begin
  perform cron.unschedule(jobid) from cron.job where jobname in (
    'daily-program',
    'recommendation-notifications',
    'morning-challenge',
    'late-morning-library',
    'afternoon-course'
  );
end;
$$;

-- 1. Morning Daily Challenge: 07:15 WAT = 06:15 UTC
select cron.schedule('morning-challenge', '15 6 * * *', $$select public.generate_morning_challenge_notification();$$);

-- 2. Late Morning Library / Book: 11:30 WAT = 10:30 UTC
select cron.schedule('late-morning-library', '30 10 * * *', $$select public.generate_late_morning_library_notification();$$);

-- 3. Afternoon Course Recommendation: 15:00 WAT = 14:00 UTC
select cron.schedule('afternoon-course', '0 14 * * *', $$select public.generate_afternoon_course_notification();$$);

-- 4. Evening Tomorrow's Programme: 18:30 WAT = 17:30 UTC
select cron.schedule('daily-program', '30 17 * * *', $$select public.generate_daily_program();$$);

revoke execute on function public.generate_morning_challenge_notification(timestamptz) from public, anon, authenticated;
revoke execute on function public.generate_late_morning_library_notification(timestamptz) from public, anon, authenticated;
revoke execute on function public.generate_afternoon_course_notification(timestamptz) from public, anon, authenticated;
revoke execute on function public.generate_recommendation_notifications(timestamptz) from public, anon, authenticated;
