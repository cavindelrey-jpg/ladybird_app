-- ============================================================================
-- xp_repository.dart reads/writes xpBalance, lifetimeXP, xpEarnedToday,
-- xpEarnedTodayDate directly on the Firestore user doc (bypassing the
-- AppUser model's own toFirestore/fromFirestore entirely) — the real,
-- currently-active XP ledger, distinct from AppUser.xpTotal which its own
-- header comment calls deprecated. Confirmed live in the export: every
-- real user doc has these fields populated with real numbers. Missed in
-- the previous pass because they only show up by grepping the repository,
-- not the model.
--
-- name_lower: messaging_repository.dart:393 orderBy()s this for the
-- friend-search flow — denormalized lowercase name, maintained by the app
-- on every profile write, not derived by a query.
--
-- favorite_subjects: present with real data in the export, no code path
-- reads it currently (grepped, no hits) — kept for completeness per
-- "transfer everything" rather than silently dropped as dead data.
-- ============================================================================

alter table public.users
  add column if not exists xp_balance integer not null default 0,
  add column if not exists lifetime_xp integer not null default 0,
  add column if not exists xp_earned_today integer not null default 0,
  add column if not exists xp_earned_today_date timestamptz,
  add column if not exists name_lower text not null default '',
  add column if not exists favorite_subjects text[] not null default '{}';

create index if not exists users_name_lower_idx on public.users (name_lower);
