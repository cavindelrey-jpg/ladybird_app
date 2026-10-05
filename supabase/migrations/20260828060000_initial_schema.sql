-- ============================================================================
-- Academia Cameroon — Firestore -> Supabase (Postgres) migration schema
-- Phase 1 of the Firebase -> Supabase runbook. Source of truth for table
-- shapes is MIGRATION_INVENTORY.md (repo root) — every table below traces
-- back to a specific Firestore collection documented there.
--
-- Scope: this file covers exactly the four items called out for Phase 1:
--   1. student_accounts   (replaces schools/{id}/seats)
--   2. user_role enum + RLS enablement (mirrors the 6-tier role system in
--      firestore.rules / lib/models/app_user.dart)
--   3. library_items / courses / magazine_articles — kept global, with a
--      nullable institution_id added for future per-school scoping
--   4. serials — replaces the serials/{code} collection + its claim/
--      revoke/release transaction logic in serial_repository.dart
--
-- Out of scope (intentionally not modeled here — no ask for them yet):
-- clubs, marks, messaging/chat, xp/gamification, tests, announcements,
-- timetable/attendance/assignments, audit_logs, subscriptions. See
-- MIGRATION_INVENTORY.md section 1 for the full collection list.
--
-- RLS policies are intentionally NOT written yet (Phase 2). Every table
-- has RLS enabled (so it defaults to deny-all, matching Firestore's
-- default-deny semantics) with a TODO comment describing what Phase 2
-- needs to implement, referencing the matching firestore.rules block.
--
-- Do not apply this to any database yet.
-- ============================================================================

create extension if not exists pgcrypto;

-- ============================================================================
-- Enums
-- ============================================================================

-- Mirrors UserRole in lib/models/app_user.dart:5-12 and the ordinal
-- comparison in firestore.rules:41-46 (roleLevel/hasMinRole). Order here
-- matches ascending privilege — Phase 2's role_level() helper can rely on
-- enum declaration order via a CASE, same as the Firestore rules do.
create type user_role as enum (
  'guest',
  'student',
  'lecturer',
  'department_admin',
  'school_admin',
  'super_admin'
);

-- Mirrors AccountStatus in lib/models/app_user.dart:15, reused by
-- student_accounts.status (see MIGRATION_INVENTORY.md's field-gap note:
-- Firestore's actual seat docs only ever use unassigned/assigned/active/
-- suspended — never any other value).
create type account_status as enum (
  'unassigned',
  'assigned',
  'active',
  'suspended'
);

-- Mirrors SerialStatus in lib/models/serial_number.dart:14.
create type serial_status as enum (
  'unclaimed',
  'claimed',
  'revoked'
);

-- ============================================================================
-- institutions
-- Supporting table — FK target for institution_id everywhere below. Kept
-- minimal (just enough to scope/join against); not a full port of every
-- Institution field (branding colors, features, etc. — out of scope here).
-- ============================================================================
create table if not exists public.institutions (
  id           uuid primary key default gen_random_uuid(),
  school_code  text unique,
  school_name  text not null,
  suspended    boolean not null default false,
  created_at   timestamptz not null default now()
);

-- ============================================================================
-- users
-- Supporting table — 1:1 with Supabase Auth, holds the role used by every
-- RLS policy below. Minimal columns; the full AppUser model (xp, streaks,
-- bio, etc.) is out of scope for this pass.
-- ============================================================================
create table if not exists public.users (
  id              uuid primary key references auth.users (id) on delete cascade,
  email           text not null unique,
  name            text,
  role            user_role not null default 'student',
  institution_id  uuid references public.institutions (id) on delete set null,
  created_at      timestamptz not null default now()
);

create index if not exists users_institution_id_idx on public.users (institution_id);
create index if not exists users_role_idx on public.users (role);

-- Auto-create a public.users row on Supabase Auth signup, same pattern as
-- the generic schema drafted earlier in supabase/schema.sql's history —
-- kept here since nothing else populates this table otherwise.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.users (id, email, name)
  values (new.id, new.email, new.raw_user_meta_data ->> 'name')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================================
-- 1. student_accounts
-- Replaces schools/{schoolId}/seats/{seatId} (lib/repositories/
-- accounts_repository.dart, lib/models/student_account.dart). Firestore
-- nests seats under a school doc; here institution_id is a plain FK
-- instead of a parent path.
--
-- Field-gap note (see MIGRATION_INVENTORY.md "Notes carried into Phase 1"):
-- email, hashed_password, assigned_at, activated_at, assigned_by don't
-- exist on the live Firestore seat docs today. They're included here per
-- the requested shape as a superset to design for — the Phase 5 import
-- script should not assume Firestore has source data for them.
-- ============================================================================
create table if not exists public.student_accounts (
  account_id            uuid primary key default gen_random_uuid(),
  institution_id        uuid not null references public.institutions (id) on delete cascade,

  -- Set once the seat is claimed and a real Supabase Auth user exists for
  -- it (mirrors the Firestore flow: a seat can exist before any auth
  -- account does). Null while status is 'unassigned'/'assigned'.
  user_id               uuid references public.users (id) on delete set null,

  student_name          text not null,
  email                 text unique,
  class_level           text not null,

  -- Plaintext, short-lived first-login password shown to the student once
  -- (matches tempPassword in student_account.dart — carried over as-is
  -- per the requested column list, not a new design choice made here).
  temp_password         text,
  -- Populated once the student sets their own password at first login;
  -- tempPassword should be cleared at that point (Phase 2/6 concern, not
  -- enforced by a constraint here).
  hashed_password        text,

  status                account_status not null default 'unassigned',
  assigned_at           timestamptz,
  activated_at          timestamptz,
  assigned_by           uuid references public.users (id) on delete set null,
  payment_ref           text,
  admin_access_revoked  boolean not null default false,

  created_at            timestamptz not null default now()
);

create index if not exists student_accounts_institution_id_idx
  on public.student_accounts (institution_id);
create index if not exists student_accounts_status_idx
  on public.student_accounts (status);
create index if not exists student_accounts_user_id_idx
  on public.student_accounts (user_id);

alter table public.student_accounts enable row level security;
-- TODO (Phase 2): mirror firestore.rules schools/{id}/seats block —
--   read/update: any signed-in user (the claim flow itself needs to read
--     before it knows who it belongs to); tighten if that's too broad.
--   insert/delete: institution_id-scoped school_admin+ only
--     (canManageSchool() && isOwnSchool(schoolId) in firestore.rules:159-166).
--   Additionally restrict which columns a student (vs. an admin) can
--     touch on update — Firestore rules don't currently do per-field
--     restriction here; Postgres RLS + column privileges can do better.

-- ============================================================================
-- 4. serials
-- Replaces serials/{serialCode} (lib/repositories/serial_repository.dart).
-- code is the natural key (Firestore doc ID = the serial code itself —
-- SerialRepository.preview()/claim() look a serial up directly by code,
-- so this keeps that lookup a single indexed PK read instead of adding a
-- surrogate uuid + a unique index on top).
--
-- The CHECK constraint below encodes the same invariant the (undeployed —
-- see MIGRATION_INVENTORY.md flag) firestore.rules serials block enforces
-- procedurally: unclaimed serials have no claimant, claimed serials always
-- have both claimed_by and claimed_at. Verified against the actual
-- claim()/release()/revoke() bodies in serial_repository.dart:95-190 —
-- revoke() only ever flips status and deliberately leaves claimed_by/
-- claimed_at untouched (a revoked serial keeps its claim history), so
-- 'revoked' is intentionally unconstrained here.
-- ============================================================================
create table if not exists public.serials (
  code            text primary key,
  institution_id  uuid not null references public.institutions (id) on delete cascade,
  status          serial_status not null default 'unclaimed',
  class_level     text,
  note            text,
  claimed_by      uuid references public.users (id) on delete set null,
  claimed_at      timestamptz,
  created_at      timestamptz not null default now(),

  constraint serials_claim_fields_consistent check (
    (status = 'unclaimed' and claimed_by is null and claimed_at is null)
    or (status = 'claimed' and claimed_by is not null and claimed_at is not null)
    or (status = 'revoked')
  )
);

create index if not exists serials_institution_id_idx on public.serials (institution_id);
create index if not exists serials_status_idx on public.serials (status);
create index if not exists serials_claimed_by_idx on public.serials (claimed_by);

alter table public.serials enable row level security;
-- TODO (Phase 2): server-only write policy. Firestore's intended rule
--   (see the undeployed firestore (1).rules:193-222) allows an
--   authenticated user to transition their OWN claim (unclaimed->claimed,
--   or claimed->unclaimed rollback for the same claimant) directly, and
--   restricts create/delete + arbitrary status changes (e.g. ->revoked)
--   to school_admin+. The claim/release compare-and-swap is exactly the
--   kind of thing that's safer as a SECURITY DEFINER Postgres function
--   (an RPC) than as a client-side UPDATE gated by RLS — consider that
--   instead of a literal 1:1 policy port when Phase 2 writes this.
--   Read policy: public (matches "allow read: if true" in both rules
--   file versions — a serial's institution branding needs to be visible
--   pre-auth for the claim-seat preview screen).

-- ============================================================================
-- 3. library_items / courses / magazine_articles
-- All three currently have NO institution concept in Firestore (see
-- MIGRATION_INVENTORY.md item 1 — public_courses and articles have none
-- at all; library's optional schoolId is never used as a query filter).
-- institution_id is added here nullable and unindexed-by-necessity-only
-- (indexed anyway, since a null-heavy index is still useful once rows
-- start getting scoped) so per-school scoping is a backfill + query
-- change later, not a schema rewrite.
-- ============================================================================

-- Replaces library/{id} (lib/models/library_item.dart, the LIVE Library
-- backing collection — not the dead-code academic_content one).
create table if not exists public.library_items (
  id             uuid primary key default gen_random_uuid(),
  title          text not null,
  author         text,
  subject        text,
  content_type   text not null default 'note',
  size_label     text,
  views          integer not null default 0,
  thumbnail_url  text,
  is_premium     boolean not null default false,
  download_url   text,
  total_pages    integer,

  -- Nullable on purpose: global content today, per-school scoping later.
  institution_id uuid references public.institutions (id) on delete set null,

  created_at     timestamptz not null default now()
);

create index if not exists library_items_institution_id_idx
  on public.library_items (institution_id);
create index if not exists library_items_subject_idx on public.library_items (subject);

alter table public.library_items enable row level security;
-- TODO (Phase 2): public read (or signed-in-only — confirm against actual
--   library_page.dart usage); write restricted to lecturer+ uploader,
--   same shape as canUploadContent() in firestore.rules.

-- Replaces public_courses/{id} (lib/models/public_course.dart) — the
-- global marketplace Course shown on the Courses tab. NOT the same as
-- the school-scoped schools/{id}/courses subcollection (lib/models/
-- course.dart), which already has its own required schoolId and is out
-- of scope for this table.
create table if not exists public.courses (
  id                uuid primary key default gen_random_uuid(),
  creator_id        uuid references public.users (id) on delete set null,
  title             text not null,
  description       text,
  body              text,
  body_delta        jsonb,
  category          text,
  tags              text[] not null default '{}',
  subject           text,
  level             text,
  topic             text,
  difficulty        text,
  sort_order        double precision not null default 0,
  prerequisite_ids  uuid[] not null default '{}',
  cover_image_url   text,
  published         boolean not null default true,
  enrolled_count    integer not null default 0,
  avg_rating        numeric(3,2) not null default 0,
  rating_count      integer not null default 0,
  like_count        integer not null default 0,
  comment_count     integer not null default 0,

  -- Nullable on purpose: global content today, per-school scoping later.
  institution_id    uuid references public.institutions (id) on delete set null,

  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index if not exists courses_institution_id_idx on public.courses (institution_id);
create index if not exists courses_creator_id_idx on public.courses (creator_id);
create index if not exists courses_published_idx on public.courses (published);

alter table public.courses enable row level security;
-- TODO (Phase 2): public read of published courses; any signed-in user
--   can create/update their own (creator_id = auth.uid()); no per-role
--   gating found in firestore.rules for public_courses specifically —
--   confirm that's intentional (marketplace content, not school content)
--   before copying a stricter policy over from courses/library.

-- Replaces articles/{id} (lib/models/magazine_article.dart).
create table if not exists public.magazine_articles (
  id                 uuid primary key default gen_random_uuid(),
  author_id          uuid references public.users (id) on delete set null,
  title              text not null,
  description        text,
  body               text,
  body_delta         jsonb,
  category           text,
  tags               text[] not null default '{}',
  thumbnail_url      text,
  featured           boolean not null default false,
  read_count         integer not null default 0,
  comment_count      integer not null default 0,
  like_count         integer not null default 0,
  pending_author_xp  integer not null default 0,
  published          boolean not null default true,

  -- Nullable on purpose: global content today, per-school scoping later.
  -- Mirrors articles.schoolId, which exists in Firestore but is never
  -- used as a query filter anywhere found in the audit.
  institution_id     uuid references public.institutions (id) on delete set null,

  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create index if not exists magazine_articles_institution_id_idx
  on public.magazine_articles (institution_id);
create index if not exists magazine_articles_author_id_idx
  on public.magazine_articles (author_id);
create index if not exists magazine_articles_published_idx
  on public.magazine_articles (published);

alter table public.magazine_articles enable row level security;
-- TODO (Phase 2): public read of published articles; author-only write
--   for their own drafts/posts, same pattern as courses above.
