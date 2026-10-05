-- ============================================================================
-- Brings public.users up to full parity with lib/models/app_user.dart's
-- AppUser — the original users table (schema.sql) was intentionally
-- minimal for the narrower Phase 1 request; the Flutter client rewrite
-- needs every field AppUser actually reads/writes, or auth_service.dart
-- and the repositories have nowhere to put real data.
--
-- Column names/types map 1:1 to AppUser.toFirestore()/fromFirestore()
-- (app_user.dart:199-264). account_status already exists (schema.sql) and
-- matches AccountStatus's values exactly, reused here rather than
-- redefined.
-- ============================================================================

create type account_type as enum ('independent', 'linked', 'guest');

alter table public.users
  add column if not exists role_name text not null default '',
  add column if not exists account_type account_type not null default 'independent',
  add column if not exists status account_status not null default 'active',
  add column if not exists serial_number text,
  add column if not exists department_id text,
  add column if not exists class_level text not null default '',
  add column if not exists subject text,
  add column if not exists course_ids uuid[] not null default '{}',
  add column if not exists is_first_login boolean not null default false,
  add column if not exists admin_access_revoked boolean not null default false,
  add column if not exists is_premium boolean not null default false,
  add column if not exists bio text not null default '',
  add column if not exists education_level text not null default '',
  add column if not exists quick_access_usage jsonb not null default '{}'::jsonb,
  add column if not exists xp_total integer not null default 0,
  add column if not exists streak_days integer not null default 0,
  add column if not exists last_active_date text,
  add column if not exists week_activity_dates text[] not null default '{}',
  add column if not exists continue_reading_item_id text,
  add column if not exists continue_reading_title text,
  add column if not exists continue_reading_page integer not null default 1,
  add column if not exists continue_reading_total_pages integer;
