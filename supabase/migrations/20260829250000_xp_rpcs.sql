-- ============================================================================
-- XpRepository.awardXp()/spendXp() were Firestore transactions specifically
-- to close a read-then-write race (two concurrent awards both reading
-- "150/200 used today" and both landing under the cap). `select ... for
-- update` gives the same guarantee here — the row lock blocks a second
-- concurrent call until the first commits.
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
begin
  if p_raw_amount <= 0 then return 0; end if;

  select xp_earned_today, xp_earned_today_date into v_earned_today, v_earned_date
    from public.users where id = p_user_id for update;
  if not found then raise exception 'User not found'; end if;

  if v_earned_date is null or v_earned_date::date <> v_now::date then
    v_earned_today := 0;
  end if;

  v_room := p_daily_cap - v_earned_today;
  v_to_award := greatest(0, least(p_raw_amount, greatest(v_room, 0)));
  if v_to_award <= 0 then return 0; end if;

  update public.users set
    xp_balance = xp_balance + v_to_award,
    lifetime_xp = lifetime_xp + v_to_award,
    xp_earned_today = v_earned_today + v_to_award,
    xp_earned_today_date = v_now
    where id = p_user_id;

  insert into public.xp_transactions (user_id, type, source, amount, article_id, ref_id, occurred_at)
    values (p_user_id, 'earn', p_source, v_to_award, p_article_id, p_ref_id, v_now);

  return v_to_award;
end;
$$;

create or replace function public.spend_xp(p_user_id uuid, p_paper_id text, p_cost integer)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_balance integer;
begin
  select xp_balance into v_balance from public.users where id = p_user_id for update;
  if not found then raise exception 'User not found'; end if;
  if v_balance < p_cost then
    raise exception 'Not enough XP — need %, have %', p_cost, v_balance;
  end if;

  update public.users set xp_balance = xp_balance - p_cost where id = p_user_id;

  insert into public.unlocked_papers (user_id, paper_id, unlocked_via, unlocked_at)
    values (p_user_id, p_paper_id, 'xp', now())
    on conflict (user_id, paper_id) do nothing;

  insert into public.xp_transactions (user_id, type, source, amount, paper_id, occurred_at)
    values (p_user_id, 'spend', 'paper_unlock', p_cost, p_paper_id, now());
end;
$$;

alter publication supabase_realtime add table public.xp_transactions;
alter publication supabase_realtime add table public.unlocked_papers;
