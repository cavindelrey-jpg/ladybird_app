-- ============================================================================
-- greenhills_app/ladybird_app additions on top of the shared XP/magazine
-- system:
--   1. Four new XP sources (production_plan.md §4.2 Clubs Q&A + Daily
--      Learning) — the *rate* for each still lives client-side in
--      xp_transaction.dart's XpSource.baseXp; this migration only widens
--      the xp_source enum so award_xp() accepts them.
--   2. Per-category daily XP allowances (§4.4 quiz / §4.5 magazine),
--      metered ON TOP OF (never instead of) the existing shared
--      kDailyXpCap pool — mirrors XpRepository.awardXp()'s old Firestore
--      transaction logic, moved into award_xp() itself since that's
--      already a security definer RPC doing the row lock.
--   3. Magazine §4.5 formula-based, 24h-delayed, once-per-article XP
--      settlement: share tracking (article_shares, mirroring
--      article_likes) + magazine_articles.share_count/magazine_xp_settled,
--      and the settle_magazine_xp_if_due() RPC.
-- Same shared tables as academia-cameroon; the category columns/new enum
-- values are simply unused there (its own awardXp call path never sets
-- them since it never sends a quiz/magazine-category source through this
-- path any differently).
-- ============================================================================

alter type public.xp_source add value if not exists 'club_question';
alter type public.xp_source add value if not exists 'club_answer';
alter type public.xp_source add value if not exists 'club_best_answer';
alter type public.xp_source add value if not exists 'daily_learning';

alter table public.users
  add column if not exists quiz_xp_earned_today integer not null default 0,
  add column if not exists quiz_xp_earned_today_date timestamptz,
  add column if not exists magazine_xp_earned_today integer not null default 0,
  add column if not exists magazine_xp_earned_today_date timestamptz;

alter table public.magazine_articles
  add column if not exists share_count integer not null default 0,
  add column if not exists magazine_xp_settled boolean not null default false;

create table if not exists public.article_shares (
  article_id  uuid not null references public.magazine_articles (id) on delete cascade,
  user_id     uuid not null references public.users (id) on delete cascade,
  shared_at   timestamptz not null default now(),
  primary key (article_id, user_id)
);

alter table public.article_shares enable row level security;
create policy "article_shares_select_all" on public.article_shares for select using (true);
create policy "article_shares_insert_own" on public.article_shares for insert
  with check (user_id = auth.uid());
