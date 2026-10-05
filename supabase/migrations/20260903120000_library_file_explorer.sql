-- Academia Library redesign: File Explorer.
--
-- Per user spec: the Library homepage is a discovery entry page (File
-- Explorer nav + Recommended for You + Recent Reads), and tapping one of
-- the top-level categories (Past Papers / Notes / Documents / Books) opens
-- a genuine, admin-editable folder tree — not a fixed Level->Subject->Topic
-- taxonomy like Courses.
--
-- Why not reuse the Courses IA: real academic_content data was checked
-- before building this (see the Courses IA postmortem — building a
-- hierarchy the real data doesn't match makes content silently invisible).
-- `level` is blank or the placeholder 'All Levels' for 30/31 real rows and
-- there is no `topic` column at all, so a Level/Subject/Topic taxonomy has
-- almost no real backing data here. A flexible, self-referential folder
-- tree that admins populate by hand (per the user's explicit instruction)
-- has no such dependency — it starts empty and is filled deliberately.

create table if not exists public.library_folders (
  id          uuid primary key default gen_random_uuid(),
  parent_id   uuid references public.library_folders (id) on delete cascade,
  name        text not null,
  emoji       text not null default '',
  image_url   text not null default '',
  sort_order  double precision not null default 0,
  created_by  uuid references auth.users (id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists library_folders_parent_id_idx on public.library_folders (parent_id);

alter table public.library_folders enable row level security;

create policy "library_folders_select_authenticated" on public.library_folders
  for select using (auth.uid() is not null);
create policy "library_folders_write_lecturer" on public.library_folders
  for all using (public.has_min_role('lecturer')) with check (public.has_min_role('lecturer'));

-- Each academic_content row now lives in exactly one folder (nullable during
-- migration; backfilled below). Placing an item is just setting this column
-- — the same file-explorer "move" the admin UI performs.
alter table public.academic_content add column if not exists folder_id uuid references public.library_folders (id);
create index if not exists academic_content_folder_id_idx on public.academic_content (folder_id);

-- Seed exactly the 4 primary root folders named in the spec. Idempotent —
-- safe to re-run. More can be added later by an admin; this migration only
-- guarantees these 4 exist.
insert into public.library_folders (parent_id, name, emoji, sort_order)
select null, v.name, v.emoji, v.sort_order
from (values
  ('Past Papers', '📄', 1.0),
  ('Notes',       '📝', 2.0),
  ('Documents',   '📁', 3.0),
  ('Books',       '📚', 4.0)
) as v(name, emoji, sort_order)
where not exists (
  select 1 from public.library_folders f where f.parent_id is null and f.name = v.name
);

-- Backfill: place every existing item straight into its matching root
-- folder by content_type — no subfolders invented from the sparse/messy
-- level and subject data. Admins organize from here using the folder
-- management UI (create/rename/move), exactly as the spec asks for.
update public.academic_content c
set folder_id = f.id
from public.library_folders f
where c.folder_id is null
  and f.parent_id is null
  and f.name = case c.content_type
    when 'pastPaper' then 'Past Papers'
    when 'note'       then 'Notes'
    when 'book'       then 'Books'
    else 'Documents'
  end;
