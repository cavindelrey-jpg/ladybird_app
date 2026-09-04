-- 20260904000005_recommendation_notifications_cron.sql
-- Spec item 9D: "at least three recommendation notifications per day...
-- actual recommendation notifications rather than three meaningless
-- duplicate notifications." RecommendationRepository's existing
-- forCourses/forLibrary/forQuizzes (lib/repositories/
-- recommendation_repository.dart) already do real, favorite-subject-
-- weighted ranking, but entirely client-side over live Supabase reads —
-- there's no way to reuse that Dart logic from a server-side cron, and
-- reimplementing its full ranking algorithm in PL/pgSQL for every call
-- site it already serves (Courses/Library/Quizzes/Magazine/Past Papers)
-- would be a lot of duplicated logic to keep in sync forever.
--
-- This implements a deliberately SIMPLER but still genuine per-student
-- version scoped to exactly the 3 categories item 9D needs, favoring a
-- student's own favorite_subjects when they've set any, excluding
-- anything they've already viewed/attempted, and falling back to "no
-- notification for that category today" rather than fabricating one
-- when nothing new/unseen exists (same honest-silence philosophy
-- 20260903171000_daily_program_cron.sql already established for this
-- project). One run inserts up to 3 distinct notifications (course,
-- library item, quiz) per student in a single transaction.
--
-- Column names (courses.subject/level/created_at, academic_content.
-- subject/level/institution_id, tests.subject/institution_id/published,
-- course_recent_views/content_recent_views/test_attempts' user_id +
-- foreign-id columns, users.favorite_subjects/education_level) are all
-- independently confirmed via both read and write sides of this app's
-- own Dart models/repositories (lib/models/public_course.dart,
-- lib/models/academic_content.dart, lib/models/test.dart,
-- lib/repositories/public_course_repository.dart,
-- lib/repositories/academic_content_repository.dart,
-- lib/repositories/test_repository.dart, lib/models/app_user.dart) --
-- none of these tables are defined in this repo's own migrations (base
-- schema lives in the sibling greenhills_app repo this app forked from,
-- shared Supabase project), so this is deliberately NOT guessed.

create extension if not exists pg_cron;

create or replace function public.generate_recommendation_notifications()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student record;
  v_course record;
  v_content record;
  v_test record;
begin
  for v_student in
    select id, favorite_subjects, education_level, institution_id
    from public.users
    where role = 'student'
  loop
    -- Course pick: favorite-subject match first, else any unseen course.
    select c.id, c.title into v_course
      from public.courses c
      where not exists (
        select 1 from public.course_recent_views v
        where v.course_id = c.id and v.user_id = v_student.id
      )
      order by
        (v_student.favorite_subjects is not null
          and c.subject = any(v_student.favorite_subjects)) desc,
        random()
      limit 1;

    if v_course.id is not null then
      insert into public.notifications (user_id, type, title, body, deep_link_id, read)
      values (v_student.id, 'recommendation', 'New course for you',
              'Check out "' || v_course.title || '" in Academia Courses.', v_course.id, false);
    end if;

    -- Library pick: favorite-subject match first, else any unseen item.
    select ac.id, ac.title into v_content
      from public.academic_content ac
      where (ac.institution_id is null or ac.institution_id = v_student.institution_id)
        and not exists (
          select 1 from public.content_recent_views v
          where v.content_id = ac.id and v.user_id = v_student.id
        )
      order by
        (v_student.favorite_subjects is not null
          and ac.subject = any(v_student.favorite_subjects)) desc,
        random()
      limit 1;

    if v_content.id is not null then
      insert into public.notifications (user_id, type, title, body, deep_link_id, read)
      values (v_student.id, 'recommendation', 'From the Library',
              '"' || v_content.title || '" looks like a good read for you.', v_content.id, false);
    end if;

    -- Quiz pick: published, visible to this student, not yet attempted.
    select t.id, t.title into v_test
      from public.tests t
      where t.published
        and (t.institution_id is null or t.institution_id = v_student.institution_id)
        and not exists (
          select 1 from public.test_attempts a
          where a.test_id = t.id and a.user_id = v_student.id
        )
      order by
        (v_student.favorite_subjects is not null
          and t.subject = any(v_student.favorite_subjects)) desc,
        random()
      limit 1;

    if v_test.id is not null then
      insert into public.notifications (user_id, type, title, body, deep_link_id, read)
      values (v_student.id, 'recommendation', 'Quiz recommendation',
              'Try "' || v_test.title || '" — a quiz picked for you.', v_test.id, false);
    end if;
  end loop;
end;
$$;

do $$
begin
  perform cron.unschedule(jobid) from cron.job where jobname = 'recommendation-notifications';
end;
$$;

select cron.schedule('recommendation-notifications', '0 8 * * *', $$select public.generate_recommendation_notifications();$$);
