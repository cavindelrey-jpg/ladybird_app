-- 20261002020000_school_voucher_repo_parity.sql
-- Makes school-voucher issuing/redemption work on an environment built
-- ONLY from the repos (staging, CI, a local replica) -- without touching
-- whatever the shared production project already has.
--
-- Found during the 2026-10-02 QA pass: the app (SchoolAccessRepository)
--   * inserts school_vouchers.premium_tier / linked_student_voucher_id,
--     which no migration in any of the three repos creates, and
--   * calls redeem_school_voucher(p_code, p_expected_prefix, p_class_level),
--     but the only definition in the repos is academia-cameroon's 2-arg
--     version, which writes school_memberships and never sets
--     users.institution_id / school_role / class_level -- the columns this
--     app actually reads (AppUser.isSchoolMember). Production evidently has
--     a 3-arg version that predates the repos.
--
-- Everything below is a no-op where the object already exists, so the
-- live definitions win on the shared project.

alter table public.school_vouchers
  add column if not exists premium_tier text not null default 'none',
  add column if not exists linked_student_voucher_id text;

do $do$
begin
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'redeem_school_voucher'
      and pg_get_function_identity_arguments(p.oid) = 'p_code text, p_expected_prefix text, p_class_level text'
  ) then
    raise notice 'redeem_school_voucher(text,text,text) already exists -- leaving it untouched';
    return;
  end if;

  execute $fn$
  create function public.redeem_school_voucher(
    p_code text, p_expected_prefix text, p_class_level text default null
  ) returns table (out_school_id uuid, out_role text, out_premium_tier text)
  language plpgsql security definer set search_path = public as $body$
  declare
    v public.school_vouchers%rowtype;
    v_me public.users%rowtype;
    v_new_role user_role;
  begin
    if auth.uid() is null then
      raise exception 'You need to be signed in to use a code';
    end if;
    if coalesce(p_code, '') = '' then
      raise exception 'Enter a code first';
    end if;
    if p_expected_prefix is not null and split_part(p_code, '-', 1) <> p_expected_prefix then
      raise exception 'That code belongs to a different school app';
    end if;

    select * into v from public.school_vouchers where id = p_code for update;
    if v.id is null then
      raise exception 'No code found matching that entry — check it and try again';
    end if;
    if v.status = 'revoked' then
      raise exception 'This code has been revoked by the school';
    end if;
    if v.status = 'redeemed' then
      if v.redeemed_by_user_id = auth.uid() then
        raise exception 'You have already used this code';
      end if;
      raise exception 'This code has already been used';
    end if;
    if v.role in ('student') and coalesce(p_class_level, '') = '' then
      raise exception 'Choose your class to finish activating';
    end if;

    select * into v_me from public.users where id = auth.uid() for update;
    if v_me.institution_id is not null and v_me.institution_id <> v.school_id then
      raise exception 'Your account already belongs to another school';
    end if;

    v_new_role := case v.role
      when 'student'     then 'student'::user_role
      when 'parent'      then 'student'::user_role
      when 'teacher'     then 'lecturer'::user_role
      when 'classMaster' then 'lecturer'::user_role
      when 'itSupport'   then 'department_admin'::user_role
      when 'admin'       then 'school_admin'::user_role
      else 'student'::user_role
    end;
    -- A role only ever rises through a code.
    if public.role_level(v_me.role) > public.role_level(v_new_role) then
      v_new_role := v_me.role;
    end if;

    update public.school_vouchers
      set status = 'redeemed', redeemed_at = now(), redeemed_by_user_id = auth.uid()
      where id = v.id;

    update public.users set
      institution_id = v.school_id,
      school_role = v.role,
      role = v_new_role,
      class_level = case when v.role in ('student') then p_class_level else class_level end,
      class_master_of_class = case when v.role = 'classMaster' and coalesce(p_class_level, '') <> ''
                                   then p_class_level else class_master_of_class end,
      school_voucher_ref = v.id,
      account_type = 'linked',
      entitlement_tier = case when v.premium_tier in ('silver', 'gold') then v.premium_tier else entitlement_tier end,
      entitlement_source = case when v.premium_tier in ('silver', 'gold') then 'school' else entitlement_source end,
      entitlement_start_at = case when v.premium_tier in ('silver', 'gold') then now() else entitlement_start_at end,
      entitlement_source_ref = case when v.premium_tier in ('silver', 'gold') then v.id else entitlement_source_ref end,
      is_premium = is_premium or v.premium_tier in ('silver', 'gold')
    where id = auth.uid();

    out_school_id := v.school_id;
    out_role := v.role;
    out_premium_tier := v.premium_tier;
    return next;
  end;
  $body$;
  $fn$;
  execute 'revoke execute on function public.redeem_school_voucher(text, text, text) from anon';
end;
$do$;
