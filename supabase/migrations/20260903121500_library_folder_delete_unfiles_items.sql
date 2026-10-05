-- Deleting a folder should never delete real content — it should unfile it
-- (folder_id -> null, shows up as "Unfiled" until an admin re-files it).
-- The original FK had no ON DELETE clause (defaults to NO ACTION), which
-- would just block deletion of any folder holding items. This is the
-- correct default for anything touching real uploaded content.
alter table public.academic_content drop constraint if exists academic_content_folder_id_fkey;
alter table public.academic_content
  add constraint academic_content_folder_id_fkey
  foreign key (folder_id) references public.library_folders (id) on delete set null;
