-- ============================================================================
-- institutions was kept minimal in schema.sql (id/school_code/school_name/
-- suspended only) since the original request only needed it as an
-- institution_id FK target. The Flutter rewrite's Institution model
-- (lib/models/institution.dart) actually reads/writes full branding —
-- closing that gap here, same pattern as the users/courses/
-- magazine_articles column gaps found earlier in this pass.
-- ============================================================================

alter table public.institutions
  add column if not exists logo_url text,
  add column if not exists primary_color text not null default '#1A56DB',
  add column if not exists secondary_color text not null default '#3B82F6',
  add column if not exists accent_color text not null default '#F59E0B',
  add column if not exists font_family text not null default 'Inter',
  add column if not exists banner_image text,
  add column if not exists enabled_features text[] not null default '{}',
  add column if not exists tagline text,
  add column if not exists contact_email text,
  add column if not exists website_url text,
  add column if not exists country text;
