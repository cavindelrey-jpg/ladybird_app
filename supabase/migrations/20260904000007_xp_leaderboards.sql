-- 20260904000007_xp_leaderboards.sql
-- Spec item 12: a per-school leaderboard (item 12A) and a global,
-- platform-wide leaderboard (item 12B), kept strictly separate. Ranked
-- by lifetime_xp (never spendable xp_balance -- spending XP on a
-- purchase must not drop your rank, same reasoning
-- XpRepository.getBalance's own (balance, lifetime) split already
-- encodes). Scoped to role = 'student' -- staff/admin accounts aren't
-- part of a student leaderboard.
--
-- Both are SECURITY DEFINER RPCs returning only the fields a
-- leaderboard actually needs (id, name, photo, xp) rather than a
-- broadened public.users SELECT policy, for the same reason
-- get_linked_students() in 20260904000006 is an RPC and not a policy
-- change: that policy isn't defined in this repo (shared Supabase
-- project with the sibling greenhills_app repo this app forked from)
-- and can't be safely inspected or extended blind.
--
-- get_school_leaderboard enforces its own school-boundary check
-- server-side (the caller must actually belong to that school) rather
-- than trusting whatever p_school_id the client passes -- "must respect
-- school boundaries" is explicit in the spec, so this can't be a
-- client-trusted parameter alone.

create or replace function public.get_school_leaderboard(p_school_id uuid, p_limit int default 50)
returns table (user_id uuid, name text, photo_url text, lifetime_xp int, rank bigint)
language sql
security definer
set search_path = public
stable
as $$
  select u.id, u.name, u.photo_url, coalesce(u.lifetime_xp, 0),
         rank() over (order by coalesce(u.lifetime_xp, 0) desc)
  from public.users u
  where u.role = 'student'
    and u.institution_id = p_school_id
    and exists (
      -- caller must belong to the same school to see its leaderboard
      select 1 from public.users me where me.id = auth.uid() and me.institution_id = p_school_id
    )
  order by coalesce(u.lifetime_xp, 0) desc
  limit p_limit;
$$;

create or replace function public.get_global_leaderboard(p_limit int default 50)
returns table (user_id uuid, name text, photo_url text, lifetime_xp int, rank bigint)
language sql
security definer
set search_path = public
stable
as $$
  select u.id, u.name, u.photo_url, coalesce(u.lifetime_xp, 0),
         rank() over (order by coalesce(u.lifetime_xp, 0) desc)
  from public.users u
  where u.role = 'student'
  order by coalesce(u.lifetime_xp, 0) desc
  limit p_limit;
$$;
