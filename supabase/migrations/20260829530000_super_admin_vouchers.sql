-- ============================================================================
-- super_admin_vouchers
-- A one-time-use code that grants the highest platform privilege
-- (super_admin) to whoever redeems it. Deliberately its own table/RPC,
-- NOT a role value bolted onto school_vouchers: school_vouchers.school_id
-- is NOT NULL (every row is scoped to one institution), and its
-- redeem_school_voucher() RPC intentionally caps the role it can grant at
-- 'school_admin' ("a platform admin redeeming a student code stays a
-- platform admin" — see 20260829370000_school_vouchers.sql). super_admin
-- is platform-wide, not institution-scoped, so it needs its own path
-- rather than weakening that existing cap.
--
-- Only an existing super_admin can mint these (insert policy below), so
-- this bootstraps ADDITIONAL super admins, not the first one — the very
-- first super_admin still has to be set with a direct
-- `update public.users set role = 'super_admin' where email = ...`
-- run by someone with database access, same as before this migration.
-- ============================================================================

create table if not exists public.super_admin_vouchers (
  code          text primary key,
  status        text not null default 'unused'
                  check (status in ('unused', 'redeemed', 'revoked')),
  created_by    uuid not null references public.users (id) on delete restrict,
  redeemed_by   uuid references public.users (id) on delete set null,
  created_at    timestamptz not null default now(),
  redeemed_at   timestamptz,

  constraint super_admin_vouchers_redeem_fields_consistent check (
    (status = 'redeemed' and redeemed_by is not null and redeemed_at is not null)
    or (status <> 'redeemed' and redeemed_by is null and redeemed_at is null)
  )
);

alter table public.super_admin_vouchers enable row level security;

-- No general SELECT: same enumeration risk school_vouchers's comment
-- describes — even restricted to super_admin, listing every unused code
-- is more exposure than needed. Staff who minted a code already have it
-- from the INSERT's RETURNING; redemption itself goes through the RPC
-- below (security definer), never a client-side select-by-code.
create policy "super_admin_vouchers_select_super_admin"
  on public.super_admin_vouchers for select
  using (public.has_min_role('super_admin'));

create policy "super_admin_vouchers_insert_super_admin"
  on public.super_admin_vouchers for insert
  with check (
    public.has_min_role('super_admin')
    and created_by = auth.uid()
    and status = 'unused'
  );

-- Revocation only (an unused code someone wants to kill) — redemption is
-- the RPC, not a client-side update, so a compromised client can't just
-- UPDATE its way to status = 'redeemed' on its own row.
create policy "super_admin_vouchers_revoke_super_admin"
  on public.super_admin_vouchers for update
  using (public.has_min_role('super_admin') and status = 'unused')
  with check (status = 'revoked');

-- Redeems a super-admin code for the calling signed-in user: locked read
-- + status flip + role grant in one transaction, same shape as
-- redeem_school_voucher(). Role only ever rises to super_admin (it's
-- already the top of role_level()), so there's no "stays higher" branch
-- to write here.
create or replace function public.redeem_super_admin_voucher(p_code text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_status text;
begin
  if auth.uid() is null then
    raise exception 'You need to be signed in to redeem this code';
  end if;

  select status into v_status
    from public.super_admin_vouchers where code = p_code for update;

  if v_status is null then
    raise exception 'No super admin code found matching that entry';
  end if;
  if v_status = 'revoked' then
    raise exception 'This code has been cancelled';
  end if;
  if v_status = 'redeemed' then
    raise exception 'This code has already been used';
  end if;

  update public.super_admin_vouchers
    set status = 'redeemed', redeemed_at = now(), redeemed_by = auth.uid()
    where code = p_code;

  update public.users set role = 'super_admin' where id = auth.uid();
end;
$$;
