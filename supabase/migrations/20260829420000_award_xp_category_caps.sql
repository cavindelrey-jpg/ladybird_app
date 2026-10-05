-- ============================================================================
-- greenhills_app/ladybird_app's production_plan.md §4.4/§4.5: quiz XP
-- (per-academic-level cap: 120/160/200, itself capped at an overall 280/
-- day) and magazine XP (100/day) are each their OWN pool, metered ON TOP
-- OF (never instead of) the general kDailyXpCap every source still
-- shares — mirrors XpRepository.awardXp()'s old Firestore transaction
-- logic (quizXpEarnedToday/magazineXpEarnedToday fields), moved into this
-- already-row-locking RPC. A source not in either category (streak, club
-- Q&A) is metered by the general cap alone, same as before.
--
-- academia-cameroon's own call path never awards a quiz/magazine-read
-- source any differently than before -- this widens the function without
-- changing its behavior for the general-pool-only case (mcq/structural/ac/
-- magazine_read all happen to be exactly the sources gated here, but the
-- general room computation and the ledger insert are unchanged).
-- ============================================================================

create or replace function public.award_xp(
  p_user_id uuid, p_source xp_source, p_raw_amount integer, p_daily_cap integer,
  p_article_id uuid default null, p_ref_id uuid default null
) returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_earned_today integer;
  v_earned_date timestamptz;
  v_now timestamptz := now();
  v_room integer;
  v_to_award integer;
  v_education_level text;
  v_is_quiz boolean := p_source in ('mcq', 'structural', 'ac', 'test_completion');
  v_is_magazine boolean := p_source = 'magazine_read';
  v_quiz_earned_today integer;
  v_quiz_earned_date timestamptz;
  v_magazine_earned_today integer;
  v_magazine_earned_date timestamptz;
  v_cat_cap integer;
  v_cat_room integer;
begin
  if p_raw_amount <= 0 then return 0; end if;

  select xp_earned_today, xp_earned_today_date, education_level,
         quiz_xp_earned_today, quiz_xp_earned_today_date,
         magazine_xp_earned_today, magazine_xp_earned_today_date
    into v_earned_today, v_earned_date, v_education_level,
         v_quiz_earned_today, v_quiz_earned_date,
         v_magazine_earned_today, v_magazine_earned_date
    from public.users where id = p_user_id for update;
  if not found then raise exception 'User not found'; end if;

  if v_earned_date is null or v_earned_date::date <> v_now::date then
    v_earned_today := 0;
  end if;
  if v_quiz_earned_date is null or v_quiz_earned_date::date <> v_now::date then
    v_quiz_earned_today := 0;
  end if;
  if v_magazine_earned_date is null or v_magazine_earned_date::date <> v_now::date then
    v_magazine_earned_today := 0;
  end if;

  v_room := p_daily_cap - v_earned_today;

  if v_is_quiz then
    v_cat_cap := least(280, case
      when v_education_level in ('Form 1', 'Form 2', 'Form 3') then 120
      when v_education_level in ('Form 4', 'Form 5') then 160
      when v_education_level in ('Lower Sixth Arts', 'Lower Sixth Science',
           'Upper Sixth Arts', 'Upper Sixth Science', 'University',
           'Professional / Working Adult', 'Independent Learner', 'Other') then 200
      else 120
    end);
    v_cat_room := v_cat_cap - v_quiz_earned_today;
    if v_cat_room < v_room then v_room := v_cat_room; end if;
  elsif v_is_magazine then
    v_cat_cap := 100; -- kMagazineDailyXpCap
    v_cat_room := v_cat_cap - v_magazine_earned_today;
    if v_cat_room < v_room then v_room := v_cat_room; end if;
  end if;

  v_to_award := greatest(0, least(p_raw_amount, greatest(v_room, 0)));
  if v_to_award <= 0 then return 0; end if;

  update public.users set
    xp_balance = xp_balance + v_to_award,
    lifetime_xp = lifetime_xp + v_to_award,
    xp_earned_today = v_earned_today + v_to_award,
    xp_earned_today_date = v_now,
    quiz_xp_earned_today = case when v_is_quiz then v_quiz_earned_today + v_to_award else quiz_xp_earned_today end,
    quiz_xp_earned_today_date = case when v_is_quiz then v_now else quiz_xp_earned_today_date end,
    magazine_xp_earned_today = case when v_is_magazine then v_magazine_earned_today + v_to_award else magazine_xp_earned_today end,
    magazine_xp_earned_today_date = case when v_is_magazine then v_now else magazine_xp_earned_today_date end
    where id = p_user_id;

  insert into public.xp_transactions (user_id, type, source, amount, article_id, ref_id, occurred_at)
    values (p_user_id, 'earn', p_source, v_to_award, p_article_id, p_ref_id, v_now);

  return v_to_award;
end;
$$;
