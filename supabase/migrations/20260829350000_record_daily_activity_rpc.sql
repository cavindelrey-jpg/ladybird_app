-- ============================================================================
-- greenhills_app's AuthService.recordDailyActivity() wraps the streak
-- read-then-write in a Firestore transaction specifically to close a race
-- (two near-simultaneous calls both reading "not recorded yet" and both
-- awarding streak XP) that academia-cameroon's version didn't guard
-- against. Porting the fix as a `select ... for update` RPC, same pattern
-- as award_xp/spend_xp — and usable by academia-cameroon too, since it's
-- the same `users` table in the same project.
-- ============================================================================

create or replace function public.record_daily_activity(p_user_id uuid)
returns table (should_award boolean, new_streak integer)
language plpgsql security definer set search_path = public as $$
declare
  v_today text := to_char(now(), 'YYYY-MM-DD');
  v_yesterday text := to_char(now() - interval '1 day', 'YYYY-MM-DD');
  v_last_active text;
  v_current_streak integer;
  v_new_streak integer;
  v_week_dates text[];
  v_monday date := date_trunc('week', now())::date; -- ISO week starts Monday
  v_this_week text[];
  v_carried text[];
begin
  select last_active_date, streak_days, week_activity_dates
    into v_last_active, v_current_streak, v_week_dates
    from public.users where id = p_user_id for update;

  if not found then
    return query select false, 0;
    return;
  end if;

  if v_last_active = v_today then
    return query select false, coalesce(v_current_streak, 0);
    return;
  end if;

  v_new_streak := case when v_last_active = v_yesterday then coalesce(v_current_streak, 0) + 1 else 1 end;

  select array_agg(to_char(v_monday + i, 'YYYY-MM-DD')) into v_this_week from generate_series(0, 6) i;
  select array_agg(d) into v_carried from unnest(coalesce(v_week_dates, '{}')) d where d = any(v_this_week);

  update public.users set
    last_active_date = v_today,
    streak_days = v_new_streak,
    week_activity_dates = (select array_agg(distinct d) from unnest(coalesce(v_carried, '{}') || v_today) d)
    where id = p_user_id;

  return query select true, v_new_streak;
end;
$$;
