-- ============================================================================
-- greenhills_app/ladybird_app's PremiumUnlockSheet records which
-- Silver/Gold package + duration was paid for, on top of the shared
-- payments table. Same "no backend processes these yet" scope note as
-- academia-cameroon's own — this table only records that a payment was
-- INITIATED, it never grants the entitlement itself.
-- Same shared table as academia-cameroon; unused there.
-- ============================================================================

alter table public.payments
  add column if not exists tier text,
  add column if not exists package text,
  add column if not exists duration_days integer;
