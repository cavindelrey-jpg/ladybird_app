-- 20260909120000_scope_user_search_by_institution.sql
-- Find People / friend search returned nothing for every non-admin user:
-- "users_select_self_or_admin" only let a row's own owner or a
-- department_admin+ read public.users, so MessagingRepository.searchUsers(),
-- watchFriends(), and suggestedFriends() all silently came back empty for
-- students and teachers. Reported by the user as "you can't even search
-- anybody, anything."
--
-- Fix, per the user's own spec (each school-branded app -- Green Hill,
-- Ladybird, etc. -- should only surface people carrying that school's
-- code; the unbranded Academia layer should surface everyone since it has
-- no school code to scope by): a caller with no institution_id (an
-- independent/Academia-layer account) can see every user; a caller who
-- belongs to an institution can see only self, admins, and other users in
-- that same institution. Uses the existing current_institution_id()
-- SECURITY DEFINER helper (same pattern as has_min_role()) so this
-- policy's own subquery doesn't recurse into itself via RLS.
--
-- All four apps on this Supabase project (academia-cameroon, academia-web,
-- greenhills_app, ladybird_app) share this table, so this single policy
-- change fixes search/friends for all of them at once.

drop policy if exists "users_select_self_or_admin" on public.users;

create policy "users_select_self_or_institution" on public.users
  for select
  using (
    id = auth.uid()
    or has_min_role('department_admin'::user_role)
    or current_institution_id() is null
    or institution_id = current_institution_id()
  );
