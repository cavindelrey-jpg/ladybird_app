-- ============================================================================
-- greenhills_app/ladybird_app's AppUser carries two groups of fields that
-- academia-cameroon's original AppUser doesn't: a flat Entitlement grant
-- (production_plan.md §8 — tier/source/expiry, replacing a bare isPremium
-- bool) and school-membership fields (schoolRole/teachingAssignments/
-- classMasterOfClass/schoolVoucherRef) gating the marks/timetable features.
--
-- This is the SAME `public.users` table (one shared multi-tenant DB), so
-- these columns are added here rather than duplicated per-app. Per the
-- "core app first" scoping decision, only the storage is added now, all
-- defaulting to the honest "no entitlement / not a school member" state —
-- the voucher redemption flows that would ever populate them with real
-- values (lib/repositories/entitlement_repository.dart,
-- school_access_repository.dart) are an explicitly deferred follow-up.
-- academia-cameroon's own users keep reading isPremium/is_premium as
-- before; these columns are simply unused (default) for that app.
-- ============================================================================

alter table public.users
  add column if not exists entitlement_tier text not null default 'free',
  add column if not exists entitlement_source text not null default 'none',
  add column if not exists entitlement_start_at timestamptz,
  add column if not exists entitlement_expires_at timestamptz,
  add column if not exists entitlement_source_ref text,
  add column if not exists school_role text,
  add column if not exists teaching_assignments jsonb not null default '[]'::jsonb,
  add column if not exists class_master_of_class text,
  add column if not exists school_voucher_ref text;
