-- ============================================================================
-- Fixes: "users cannot properly search for other users", "the messaging
-- area feels empty", "recommendations are missing" (mission brief §6).
--
-- Root cause: public.users' only SELECT policy is
--   users_select_self_or_admin: using (id = auth.uid() or has_min_role('department_admin'))
-- (20260828060100_rls_policies.sql). Any query reading ANOTHER user's row
-- — MessagingRepository.searchUsers/watchFriends/suggestedFriends, all of
-- which query public.users directly — is silently filtered to zero rows
-- for every account below department_admin. Not an error, just an always-
-- empty result: search never finds anyone, "My Friends" shows nobody even
-- with real friendships, and "suggested friends" is always empty.
--
-- public.users also holds a genuinely sensitive column (email, unique/
-- PII) plus internal bookkeeping (xp, entitlement, status) that
-- shouldn't be broadly readable — so the fix is not to loosen the base
-- policy (Postgres RLS is row-level, not column-level; there's no way to
-- say "any row, but only these columns" via a policy alone). Instead,
-- three SECURITY DEFINER functions expose only the public-profile subset
-- (id, name, photo_url, role, role_name, account_type, institution_id) —
-- the same pattern already used for join_club/approve_club_join_request
-- elsewhere in this schema. Email and other sensitive columns are never
-- returned. The base table policy is untouched: a user's own full row
-- (email included) is still only visible to themselves or an admin.
-- ============================================================================

create or replace function public.search_users_public(p_query text, p_limit int default 20)
returns table (
  id uuid, name text, photo_url text,
  role text, role_name text, account_type text, institution_id uuid
)
language sql stable security definer set search_path = public as $$
  select u.id, u.name, u.photo_url, u.role::text, u.role_name, u.account_type::text, u.institution_id
  from public.users u
  where u.name_lower like lower(trim(p_query)) || '%'
  order by u.name_lower
  limit greatest(p_limit, 0);
$$;

create or replace function public.get_public_profiles(p_ids uuid[])
returns table (
  id uuid, name text, photo_url text,
  role text, role_name text, account_type text, institution_id uuid
)
language sql stable security definer set search_path = public as $$
  select u.id, u.name, u.photo_url, u.role::text, u.role_name, u.account_type::text, u.institution_id
  from public.users u
  where u.id = any(p_ids);
$$;

create or replace function public.suggested_profiles_by_institution(
  p_institution_id uuid, p_exclude_ids uuid[], p_limit int default 20
)
returns table (
  id uuid, name text, photo_url text,
  role text, role_name text, account_type text, institution_id uuid
)
language sql stable security definer set search_path = public as $$
  select u.id, u.name, u.photo_url, u.role::text, u.role_name, u.account_type::text, u.institution_id
  from public.users u
  where u.institution_id = p_institution_id
    and not (u.id = any(p_exclude_ids))
  limit greatest(p_limit, 0);
$$;

-- Same root cause, one more call site found while fixing this: a lecturer
-- searching for their own students to enter marks (marks_repository.dart)
-- queried public.users directly too, with the identical always-empty
-- result for the same RLS reason.
create or replace function public.search_students_public(
  p_institution_id uuid, p_query text, p_limit int default 30
)
returns table (
  id uuid, name text, photo_url text,
  role text, role_name text, account_type text, institution_id uuid
)
language sql stable security definer set search_path = public as $$
  select u.id, u.name, u.photo_url, u.role::text, u.role_name, u.account_type::text, u.institution_id
  from public.users u
  where u.institution_id = p_institution_id
    and u.role = 'student'
    and u.name_lower like '%' || lower(trim(p_query)) || '%'
  limit greatest(p_limit, 0);
$$;

grant execute on function public.search_users_public(text, int) to authenticated;
grant execute on function public.get_public_profiles(uuid[]) to authenticated;
grant execute on function public.suggested_profiles_by_institution(uuid, uuid[], int) to authenticated;
grant execute on function public.search_students_public(uuid, text, int) to authenticated;
