-- 20261002000000_lock_down_user_privilege_columns.sql
-- Found by the 2026-10-02 role-simulation QA pass (local replica of the
-- shared project: academia-cameroon + greenhills_app + this repo's
-- migrations applied in timestamp order, then real queries run as each
-- role with `set role authenticated` + JWT claims, i.e. exactly how
-- PostgREST evaluates RLS). Before this migration:
--
--   1. users_update_self (`id = auth.uid()`, no column restriction) let
--      ANY signed-in user run
--        update users set role = 'super_admin' where id = <self>
--      and likewise self-grant teaching_assignments /
--      class_master_of_class, or move themselves into another school.
--   2. has_school_role() fell back to "caller's GLOBAL role level >=
--      min_role" without checking the school, so a school_admin of
--      school A passed has_school_role(<school B>, ...) -- letting them
--      edit school B's users (users_update_admin) and read school B's
--      unused voucher codes (school_vouchers_select_staff). The same
--      admin could also promote anyone to super_admin.
--
-- Fix, in two layers:
--   * has_school_role(): the global-role fallback now only applies to
--     super_admin, to a caller whose own institution IS p_school_id, or
--     when p_school_id is NULL (platform-wide content -- 18 policies use
--     has_school_role(NULL, ...) to mean "global role >= X").
--   * A BEFORE UPDATE guard on public.users for direct client writes
--     (current_user = 'authenticated'). SECURITY DEFINER RPCs
--     (redeem_*_voucher, award_xp, spend_xp, record_daily_activity) run
--     as their owner, not 'authenticated', so they're unaffected. The
--     guard only rejects CHANGES -- re-writing a privileged column with
--     its existing value (AppUser.toSupabase() does this on sign-up) is
--     still fine.

create or replace function public.has_school_role(p_school_id uuid, min_role user_role)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.school_memberships
    where user_id = auth.uid()
      and school_id = p_school_id
      and public.role_level(role) >= public.role_level(min_role)
  ) or exists (
    select 1 from public.users
    where id = auth.uid()
      and public.role_level(role) >= public.role_level(min_role)
      -- p_school_id NULL = platform-wide content (magazine, platform
      -- courses/tests): the caller's global role is what's being asked.
      and (role = 'super_admin' or p_school_id is null or institution_id = p_school_id)
  );
$$;

create or replace function public.guard_user_privileged_columns()
returns trigger
language plpgsql
-- SECURITY INVOKER on purpose: current_user must stay 'authenticated'
-- for a direct client write, and become the owner inside a SECURITY
-- DEFINER RPC -- that's what the exemption below keys on.
security invoker
set search_path = public
as $$
declare
  v_caller public.users%rowtype;
begin
  if current_user <> 'authenticated' then
    return new; -- service role, migrations, SECURITY DEFINER RPCs
  end if;

  select * into v_caller from public.users where id = auth.uid();
  if not found then
    raise exception 'Not allowed' using errcode = '42501';
  end if;

  if new.id = auth.uid() then
    -- Self-service profile edits: name, photo, bio, class pick, reading
    -- position, etc. stay open. Anything that grants privilege, school
    -- membership, premium, or XP must come from an RPC.
    if new.role is distinct from old.role
       or new.institution_id is distinct from old.institution_id
       or new.school_role is distinct from old.school_role
       or new.teaching_assignments is distinct from old.teaching_assignments
       or new.class_master_of_class is distinct from old.class_master_of_class
       or new.school_voucher_ref is distinct from old.school_voucher_ref
       or new.status is distinct from old.status
       or new.admin_access_revoked is distinct from old.admin_access_revoked
       or new.is_premium is distinct from old.is_premium
       or new.entitlement_tier is distinct from old.entitlement_tier
       or new.entitlement_source is distinct from old.entitlement_source
       or new.entitlement_expires_at is distinct from old.entitlement_expires_at
       or new.xp_balance is distinct from old.xp_balance
       or new.lifetime_xp is distinct from old.lifetime_xp
    then
      raise exception 'You can''t change your own role, school, permissions, premium status or XP'
        using errcode = '42501';
    end if;
    return new;
  end if;

  -- Editing someone else (RLS' users_update_admin already required an
  -- admin of the target's school). Super admins may do anything.
  if v_caller.role = 'super_admin' then
    return new;
  end if;

  if old.institution_id is distinct from v_caller.institution_id then
    raise exception 'That account belongs to another school' using errcode = '42501';
  end if;
  if new.institution_id is distinct from old.institution_id then
    raise exception 'Only a super admin can move an account between schools' using errcode = '42501';
  end if;
  if new.role is distinct from old.role
     and public.role_level(new.role) >= public.role_level(v_caller.role) then
    raise exception 'You can''t grant a role equal to or above your own' using errcode = '42501';
  end if;
  if public.role_level(old.role) >= public.role_level(v_caller.role) then
    raise exception 'You can''t edit an account at or above your own role' using errcode = '42501';
  end if;
  if new.is_premium is distinct from old.is_premium
     or new.entitlement_tier is distinct from old.entitlement_tier
     or new.xp_balance is distinct from old.xp_balance
     or new.lifetime_xp is distinct from old.lifetime_xp then
    raise exception 'Premium and XP can only change through their own flows' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_user_privileged_columns on public.users;
create trigger trg_guard_user_privileged_columns
  before update on public.users
  for each row execute function public.guard_user_privileged_columns();

-- ── school_marks: value range + the student must belong to the school ──
-- Previously a lecturer authorized for (Mathematics, Form 5) could write
-- score 25 out of 20, a negative score, or a mark for a student at a
-- different school entirely. NOT VALID: enforced for every new/updated
-- row without failing the migration on any historical bad row.
alter table public.school_marks drop constraint if exists school_marks_score_range;
alter table public.school_marks
  add constraint school_marks_score_range
  check (max_score > 0 and score >= 0 and score <= max_score) not valid;

create or replace function public.guard_school_mark_student()
returns trigger
language plpgsql
-- SECURITY INVOKER on purpose: current_user must stay 'authenticated'
-- for a direct client write, and become the owner inside a SECURITY
-- DEFINER RPC -- that's what the exemption below keys on.
security invoker
set search_path = public
as $$
begin
  if current_user <> 'authenticated' then
    return new;
  end if;
  if not exists (
    select 1 from public.users s
    where s.id = new.student_id and s.institution_id = new.school_id
  ) then
    raise exception 'That student isn''t enrolled at this school' using errcode = '42501';
  end if;
  -- A teacher's (subject, class) authorization is only meaningful if the
  -- row's class_level is the student's real class -- otherwise a Form 5
  -- Maths teacher could file a Form 4 student's mark "as Form 5".
  -- School admins keep the latitude to correct historical rows.
  if not public.has_min_role('school_admin') and not exists (
    select 1 from public.users s
    where s.id = new.student_id and s.class_level = new.class_level
  ) then
    raise exception 'That student isn''t in %', new.class_level using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_school_mark_student on public.school_marks;
create trigger trg_guard_school_mark_student
  before insert or update on public.school_marks
  for each row execute function public.guard_school_mark_student();
