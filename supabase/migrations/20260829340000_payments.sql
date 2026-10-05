-- ============================================================================
-- PremiumUnlockSheet writes a pending payment record for a MoMo/Orange
-- Money unlock — no backend actually processes these yet in either the
-- Firestore or Supabase version (confirmed: no Cloud Function/Edge
-- Function exists for this despite the original comment implying one).
-- Table added so the write is real rather than pointing at nothing;
-- actual payment confirmation still needs a real backend integration,
-- out of scope here.
-- ============================================================================

create table if not exists public.payments (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.users (id) on delete cascade,
  phone_number  text not null,
  provider      text not null,
  amount        integer not null,
  currency      text not null default 'XAF',
  status        text not null default 'pending',
  created_at    timestamptz not null default now()
);

alter table public.payments enable row level security;
create policy "payments_select_own" on public.payments for select using (user_id = auth.uid());
create policy "payments_insert_own" on public.payments for insert with check (user_id = auth.uid());
