-- supabase/migrations/20261027010000_entitlement_and_roster_enhancements.sql
-- 1. Support Bronze, Silver, and Gold entitlement tiers
-- 2. Support official student names & separate account usernames on school rosters
-- 3. Multi-school tenant canonicalization helper (Ladybird, Green Hills, CFPMI)

-- ============================================================================
-- 1. Safe Schema Enhancements for school_students & users
-- ============================================================================

-- Add username & account linking columns to school_students if not present
alter table public.school_students add column if not exists username text;
alter table public.school_students add column if not exists account_id uuid references public.users (id) on delete set null;
alter table public.school_students add column if not exists user_id uuid references public.users (id) on delete set null;

create index if not exists school_students_username_idx on public.school_students (school_id, username);
create index if not exists school_students_account_id_idx on public.school_students (school_id, account_id);

-- Add official_name & username columns to public.users if not present
alter table public.users add column if not exists official_name text;
alter table public.users add column if not exists username text;

-- ============================================================================
-- 2. Canonical School UUID Resolver Helper
-- ============================================================================
create or replace function public.canonical_school_uuid(school_ident text)
returns uuid
language sql stable
as $$
  select case lower(trim(coalesce(school_ident, '')))
    when 'ladybird'   then 'e57702a0-91b1-4dd3-8d31-29bb928d3114'::uuid
    when 'lb'         then 'e57702a0-91b1-4dd3-8d31-29bb928d3114'::uuid
    when 'green_hill' then '93f2afa1-aaa1-4d15-86e8-41a15b1f94c2'::uuid
    when 'greenhill'  then '93f2afa1-aaa1-4d15-86e8-41a15b1f94c2'::uuid
    when 'gh'         then '93f2afa1-aaa1-4d15-86e8-41a15b1f94c2'::uuid
    when 'cfpmi'      then '446007a8-4389-40eb-bfa7-5452541b5a1f'::uuid
    when 'cf'         then '446007a8-4389-40eb-bfa7-5452541b5a1f'::uuid
    else case
      when school_ident ~* '^[0-9a-f-]{36}$' then school_ident::uuid
      else null
    end
  end;
$$;

-- ============================================================================
-- 3. Update redeem_school_voucher to support bronze, silver, gold
-- ============================================================================
create or replace function public.redeem_school_voucher(
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
    entitlement_tier = case when v.premium_tier in ('bronze', 'silver', 'gold') then v.premium_tier else entitlement_tier end,
    entitlement_source = case when v.premium_tier in ('bronze', 'silver', 'gold') then 'school' else entitlement_source end,
    entitlement_start_at = case when v.premium_tier in ('bronze', 'silver', 'gold') then now() else entitlement_start_at end,
    entitlement_source_ref = case when v.premium_tier in ('bronze', 'silver', 'gold') then v.id else entitlement_source_ref end,
    is_premium = is_premium or v.premium_tier in ('bronze', 'silver', 'gold')
  where id = auth.uid();

  out_school_id := v.school_id;
  out_role := v.role::text;
  out_premium_tier := v.premium_tier;
  return next;
end;
$body$;

grant execute on function public.canonical_school_uuid(text) to authenticated, anon;
grant execute on function public.redeem_school_voucher(text, text, text) to authenticated;
