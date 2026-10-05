-- ============================================================================
-- CORRECTION: earlier passes in this migration (MIGRATION_INVENTORY.md,
-- schema.sql) concluded academic_content/AcademicContentRepository was
-- dead code, never instantiated. That was wrong — grepping the actual
-- Flutter app_router.dart shows `case 'Library': return
-- AcademicContentPage(...)`, meaning AcademicContentRepository backs the
-- app's REAL, live Library tab. The `library`/LibraryItem/LibraryRepository
-- path (which schema.sql's library_items table was actually built for) is
-- the one that's genuinely dead — nothing routes to LibraryPage anywhere.
--
-- This migration adds what the real Library feature needs. The 5
-- academic_content documents + their real Firebase Storage files
-- (skipped earlier under the wrong dead-code assumption) still need a
-- separate export/storage-migration/import pass after this — schema
-- first, data next.
-- ============================================================================

create table if not exists public.academic_content (
  id                uuid primary key default gen_random_uuid(),
  title             text not null default 'Untitled',
  description       text not null default '',
  thumbnail_url     text,
  file_url          text,
  content_type      text not null default 'note', -- ContentType enum values, stored as-is (note/pastPaper/book/video/assignment/presentation/researchPaper)
  subject           text not null default '',
  institution_id    uuid references public.institutions (id) on delete set null,
  uploaded_by       uuid references public.users (id) on delete set null,
  uploader_name     text not null default 'Unknown',
  file_size_bytes   bigint,
  upload_date       timestamptz not null default now(),
  tags              text[] not null default '{}',
  views             integer not null default 0,
  downloads         integer not null default 0
);

create index if not exists academic_content_institution_id_idx on public.academic_content (institution_id);
create index if not exists academic_content_subject_idx on public.academic_content (subject);
create index if not exists academic_content_content_type_idx on public.academic_content (content_type);

alter table public.academic_content enable row level security;
create policy "academic_content_select_authenticated" on public.academic_content for select using (auth.uid() is not null);
create policy "academic_content_write_lecturer" on public.academic_content for all
  using (public.has_min_role('lecturer')) with check (public.has_min_role('lecturer'));

-- Bump views/downloads for any signed-in reader, not just lecturer+ (same
-- reasoning as increment_library_views).
create or replace function public.increment_academic_content_views(p_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Must be signed in.'; end if;
  update public.academic_content set views = views + 1 where id = p_id;
end;
$$;

create or replace function public.increment_academic_content_downloads(p_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Must be signed in.'; end if;
  update public.academic_content set downloads = downloads + 1 where id = p_id;
end;
$$;

-- content_saves: "saved to my list" marker (content_details_page.dart's
-- toggleSave) — one row per (content, user).
create table if not exists public.content_saves (
  content_id  uuid not null references public.academic_content (id) on delete cascade,
  user_id     uuid not null references public.users (id) on delete cascade,
  saved_at    timestamptz not null default now(),
  primary key (content_id, user_id)
);

alter table public.content_saves enable row level security;
create policy "content_saves_select_own" on public.content_saves for select using (user_id = auth.uid());
create policy "content_saves_insert_self" on public.content_saves for insert with check (user_id = auth.uid());
create policy "content_saves_delete_self" on public.content_saves for delete using (user_id = auth.uid());

-- content_recent_views: powers "Continue Learning" — most-recent view per
-- (content, user), upserted on every open.
create table if not exists public.content_recent_views (
  content_id  uuid not null references public.academic_content (id) on delete cascade,
  user_id     uuid not null references public.users (id) on delete cascade,
  viewed_at   timestamptz not null default now(),
  primary key (content_id, user_id)
);

alter table public.content_recent_views enable row level security;
create policy "content_recent_views_select_own" on public.content_recent_views for select using (user_id = auth.uid());
create policy "content_recent_views_upsert_self" on public.content_recent_views for insert with check (user_id = auth.uid());
create policy "content_recent_views_update_self" on public.content_recent_views for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- content_read_positions: powers Home "Continue Reading" — the PDF page a
-- user last left off on for a given content item.
create table if not exists public.content_read_positions (
  content_id   uuid not null references public.academic_content (id) on delete cascade,
  user_id      uuid not null references public.users (id) on delete cascade,
  page         integer not null default 1,
  total_pages  integer not null default 1,
  updated_at   timestamptz not null default now(),
  primary key (content_id, user_id)
);

alter table public.content_read_positions enable row level security;
create policy "content_read_positions_select_own" on public.content_read_positions for select using (user_id = auth.uid());
create policy "content_read_positions_upsert_self" on public.content_read_positions for insert with check (user_id = auth.uid());
create policy "content_read_positions_update_self" on public.content_read_positions for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());
