-- ============================================================================
-- greenhills_app/ladybird_app's ConnectSchoolScreen is the app's actual
-- front door (architecture brief items 2-6): a school app must only be
-- accessible to someone holding a valid voucher for THAT school, never to
-- any signed-in Academia account merely by being signed in. This is core
-- navigation, not one of the deferred zero-data subsystems — the app
-- can't render its landing screen without it.
--
-- "School" itself is NOT a new table: greenhills_app's School{id, code,
-- name} is exactly public.institutions{id, school_code, school_name} —
-- reusing it keeps one school-identity table in this shared multi-tenant
-- database instead of two competing ones. See lib/models/school.dart's
-- ported fromSupabase/toSupabase.
--
-- school_vouchers grants SCHOOL MEMBERSHIP + ROLE (schoolRole on AppUser),
-- deliberately separate from the still-deferred content-entitlement
-- voucher system (lib/models/voucher.dart / entitlement_repository.dart —
-- Premium Silver/Gold, not school access). id IS the normalized code
-- (mirrors the Firestore doc-id-is-the-code design) so redemption can be
-- a single locked row read inside one function, no query-then-race gap.
-- ============================================================================

create table if not exists public.school_vouchers (
  id                   text primary key,
  code                 text not null,
  school_id            uuid not null references public.institutions (id) on delete cascade,
  school_code          text not null,
  role                 text not null,
  status               text not null default 'unused',
  created_at           timestamptz not null default now(),
  redeemed_at          timestamptz,
  redeemed_by_user_id  uuid references public.users (id) on delete set null,
  created_by_uid       uuid references public.users (id) on delete set null
);

create index if not exists school_vouchers_school_id_idx on public.school_vouchers (school_id);

alter table public.school_vouchers enable row level security;

-- No general SELECT policy: unlike Firestore (which distinguishes a
-- single-document `get` from a collection `list`), Postgres RLS cannot —
-- a "signed-in users may read a code they already hold" policy would
-- also let them enumerate every other unused code via a plain `select *`.
-- Redemption is therefore an RPC (below) that reads the row server-side
-- under security definer, never a client-side select-by-id. Only staff
-- get a SELECT policy, for legitimate issued-codes management.
create policy "school_vouchers_select_staff" on public.school_vouchers for select
  using (public.has_min_role('department_admin')
         and (public.has_min_role('super_admin') or school_id = public.current_institution_id()));

create policy "school_vouchers_insert_staff" on public.school_vouchers for insert
  with check (public.has_min_role('department_admin')
              and created_by_uid = auth.uid()
              and status = 'unused'
              and (public.has_min_role('super_admin') or school_id = public.current_institution_id()));

-- Staff revocation only (redemption goes through the RPC below, not a
-- client-side update, for the same enumeration-vs-race reasons as select).
create policy "school_vouchers_update_staff" on public.school_vouchers for update
  using (public.has_min_role('department_admin')
         and (public.has_min_role('super_admin') or school_id = public.current_institution_id()))
  with check (public.has_min_role('department_admin'));

-- Redeems a school-membership code for the calling user: validates status,
-- marks the voucher redeemed, and grants schoolRole/institution/classLevel
-- on their own users row -- all inside one locked read, mirroring
-- claim_serial()'s shape. Content-privilege role only ever rises (a
-- platform admin redeeming a student code stays a platform admin), same
-- rule as SchoolAccessRepository.redeemSchoolVoucher had in Firestore.
create or replace function public.redeem_school_voucher(p_code text, p_class_level text default null)
returns table (out_school_id uuid, out_role text)
language plpgsql security definer set search_path = public as $$
declare
  v_status text;
  v_school_id uuid;
  v_role text;
  v_content_role user_role;
  v_current_role user_role;
begin
  if auth.uid() is null then
    raise exception 'You need to be signed in to link a school';
  end if;

  select status, school_id, role into v_status, v_school_id, v_role
    from public.school_vouchers where id = p_code for update;

  if v_status is null then
    raise exception 'No school code found matching that entry';
  end if;
  if v_status = 'revoked' then
    raise exception 'This code has been cancelled';
  end if;
  if v_status = 'redeemed' then
    raise exception 'This code has already been used';
  end if;

  update public.school_vouchers
    set status = 'redeemed', redeemed_at = now(), redeemed_by_user_id = auth.uid()
    where id = p_code;

  v_content_role := case v_role
    when 'student'     then 'student'::user_role
    when 'parent'      then 'guest'::user_role
    when 'teacher'     then 'lecturer'::user_role
    when 'classMaster' then 'lecturer'::user_role
    when 'admin'       then 'school_admin'::user_role
    else 'student'::user_role
  end;

  select role into v_current_role from public.users where id = auth.uid();

  update public.users u set
    institution_id = v_school_id,
    school_role = v_role,
    school_voucher_ref = p_code,
    class_master_of_class = case when v_role = 'classMaster' and p_class_level is not null and p_class_level <> ''
                                  then p_class_level else u.class_master_of_class end,
    class_level = case when p_class_level is not null and p_class_level <> '' then p_class_level else u.class_level end,
    role = case when public.role_level(v_current_role) < public.role_level(v_content_role)
                then v_content_role else v_current_role end
  where u.id = auth.uid();

  return query select v_school_id, v_role;
end;
$$;
