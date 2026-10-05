-- ============================================================================
-- academia_premium_vouchers
-- A one-time-use code that grants the individual Premium tier (AppUser.
-- isPremium -- unlocks every past paper platform-wide, independent of any
-- institution; see account_choice_screen.dart's own description of this
-- tier) to whoever redeems it, without going through the MoMo/Orange Money
-- payment flow (widgets/premium_unlock_sheet.dart).
--
-- Deliberately its own table/RPC, not a role bolted onto school_vouchers
-- or super_admin_vouchers: this grants a CONTENT ENTITLEMENT
-- (users.is_premium), not a role or school membership, and unlike those
-- two this app has no Silver/Gold tier concept on AppUser (just the one
-- boolean) -- so this is a deliberately simpler single-tier design than
-- ladybird_app/greenhills_app's AC-prefixed two-tier voucher redesign,
-- matched to what actually exists on this app's AppUser model today.
--
-- Same "id IS the code" + security-definer-RPC-only-redemption pattern as
-- every other voucher table in this schema (see
-- 20260829530000_super_admin_vouchers.sql's header for the reasoning).
-- ============================================================================

create table if not exists public.academia_premium_vouchers (
  code          text primary key,
  status        text not null default 'unused'
                  check (status in ('unused', 'redeemed', 'revoked')),
  created_by    uuid not null references public.users (id) on delete restrict,
  redeemed_by   uuid references public.users (id) on delete set null,
  created_at    timestamptz not null default now(),
  redeemed_at   timestamptz,

  constraint academia_premium_vouchers_redeem_fields_consistent check (
    (status = 'redeemed' and redeemed_by is not null and redeemed_at is not null)
    or (status <> 'redeemed' and redeemed_by is null and redeemed_at is null)
  )
);

alter table public.academia_premium_vouchers enable row level security;

-- No general SELECT for non-admins: same code-enumeration risk every
-- other voucher table's comment describes -- listing every unused code
-- would let anyone who can read the table redeem all of them. Minting is
-- kept at super_admin (not department_admin/school_admin) since this
-- bypasses a real 5,000 FCFA payment -- deliberately the same trust level
-- as super_admin_vouchers itself, not the lower bar school_vouchers uses.
create policy "academia_premium_vouchers_select_super_admin"
  on public.academia_premium_vouchers for select
  using (public.has_min_role('super_admin'));

create policy "academia_premium_vouchers_insert_super_admin"
  on public.academia_premium_vouchers for insert
  with check (
    public.has_min_role('super_admin')
    and created_by = auth.uid()
    and status = 'unused'
  );

-- Revocation only (an unused code someone wants to kill) -- redemption is
-- the RPC below, not a client-side update, so a compromised client can't
-- just UPDATE its way to status = 'redeemed' on its own row.
create policy "academia_premium_vouchers_revoke_super_admin"
  on public.academia_premium_vouchers for update
  using (public.has_min_role('super_admin') and status = 'unused')
  with check (status = 'revoked');

-- Redeems a Premium code for the calling signed-in user: locked read +
-- status flip + entitlement grant in one transaction, same shape as
-- redeem_super_admin_voucher(). is_premium only ever goes true -> true or
-- false -> true, never gets set back to false by this path.
create or replace function public.redeem_academia_premium_voucher(p_code text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_status text;
begin
  if auth.uid() is null then
    raise exception 'You need to be signed in to redeem this code';
  end if;

  select status into v_status
    from public.academia_premium_vouchers where code = p_code for update;

  if v_status is null then
    raise exception 'No Premium code found matching that entry';
  end if;
  if v_status = 'revoked' then
    raise exception 'This code has been cancelled';
  end if;
  if v_status = 'redeemed' then
    raise exception 'This code has already been used';
  end if;

  update public.academia_premium_vouchers
    set status = 'redeemed', redeemed_at = now(), redeemed_by = auth.uid()
    where code = p_code;

  update public.users set is_premium = true where id = auth.uid();
end;
$$;
