-- ============================================================================
-- Seeds a sensible default folder structure under "Past Papers", per the
-- user's explicit Library File Explorer spec:
--   Past Papers -> Exam System -> Level -> Subject -> Paper
-- e.g. Past Papers -> GCE -> O-Level -> Physics -> Paper 1.
--
-- library_folders is a genuine generic tree (see 20260903120000's header
-- comment) that an admin can already build by hand one folder at a time —
-- this migration just ships day-one content instead of an empty shell, per
-- the spec's own "ship with a sensible default structure... Super Admin
-- must be able to modify it" requirement. Every folder created here is
-- exactly as editable/renameable/deletable afterward as one an admin
-- creates through the app itself — nothing here is hardcoded into the app,
-- only seeded into the data.
--
-- GCE (O-Level/A-Level, with real example subjects and the Paper 1/2 vs
-- Paper 1/2/3 split the spec calls out) is seeded in full. Other exam
-- systems the spec names (Baccalauréat, Probatoire, WAEC/other, SAT) get
-- only their top-level folder — this migration doesn't have confident,
-- verified subject/series/paper data for those systems, and inventing one
-- would risk shipping wrong academic structure. An admin fills those in
-- using the same "New folder" flow already in the app; the folders exist
-- so there's an obvious place to start.
--
-- Idempotent: every insert is guarded by "where not exists", safe to re-run.
-- ============================================================================

do $$
declare
  v_past_papers uuid;
  v_gce uuid;
  v_level uuid;
  v_subject uuid;
  v_exam_system record;
  v_subject_name text;
  v_paper_num int;
begin
  select id into v_past_papers from public.library_folders
    where parent_id is null and name = 'Past Papers';
  if v_past_papers is null then
    raise notice 'Past Papers root folder not found — skipping hierarchy seed (run 20260903120000 first)';
    return;
  end if;

  -- GCE
  select id into v_gce from public.library_folders
    where parent_id = v_past_papers and name = 'GCE';
  if v_gce is null then
    insert into public.library_folders (parent_id, name, emoji, sort_order)
      values (v_past_papers, 'GCE', '🎓', 1.0)
      returning id into v_gce;
  end if;

  -- O-Level and A-Level get explicit blocks below (rather than one generic
  -- loop) since their subject lists and paper counts differ.

  -- O-Level
  select id into v_level from public.library_folders
    where parent_id = v_gce and name = 'O-Level';
  if v_level is null then
    insert into public.library_folders (parent_id, name, emoji, sort_order)
      values (v_gce, 'O-Level', '📘', 1.0)
      returning id into v_level;
  end if;
  foreach v_subject_name in array array['Mathematics', 'Physics', 'Computer Science', 'Geography', 'Additional Mathematics']
  loop
    select id into v_subject from public.library_folders
      where parent_id = v_level and name = v_subject_name;
    if v_subject is null then
      insert into public.library_folders (parent_id, name, emoji, sort_order)
        values (v_level, v_subject_name, '📂', 0)
        returning id into v_subject;
    end if;
    for v_paper_num in 1..2 loop
      insert into public.library_folders (parent_id, name, emoji, sort_order)
        select v_subject, 'Paper ' || v_paper_num, '📄', v_paper_num
        where not exists (
          select 1 from public.library_folders
          where parent_id = v_subject and name = 'Paper ' || v_paper_num
        );
    end loop;
  end loop;

  -- A-Level
  select id into v_level from public.library_folders
    where parent_id = v_gce and name = 'A-Level';
  if v_level is null then
    insert into public.library_folders (parent_id, name, emoji, sort_order)
      values (v_gce, 'A-Level', '📗', 2.0)
      returning id into v_level;
  end if;
  foreach v_subject_name in array array['Mathematics', 'Physics', 'Computer Science']
  loop
    select id into v_subject from public.library_folders
      where parent_id = v_level and name = v_subject_name;
    if v_subject is null then
      insert into public.library_folders (parent_id, name, emoji, sort_order)
        values (v_level, v_subject_name, '📂', 0)
        returning id into v_subject;
    end if;
    for v_paper_num in 1..3 loop
      insert into public.library_folders (parent_id, name, emoji, sort_order)
        select v_subject, 'Paper ' || v_paper_num, '📄', v_paper_num
        where not exists (
          select 1 from public.library_folders
          where parent_id = v_subject and name = 'Paper ' || v_paper_num
        );
    end loop;
  end loop;

  -- Other exam systems named in the spec — top-level folder only, left for
  -- an admin to populate (see header comment for why).
  for v_exam_system in
    select * from (values
      ('Baccalauréat', '🇨🇲', 2.0),
      ('Probatoire',   '📝', 3.0),
      ('WAEC / Other Examination Systems', '🌍', 4.0),
      ('SAT',          '🇺🇸', 5.0)
    ) as t(name, emoji, sort_order)
  loop
    insert into public.library_folders (parent_id, name, emoji, sort_order)
      select v_past_papers, v_exam_system.name, v_exam_system.emoji, v_exam_system.sort_order
      where not exists (
        select 1 from public.library_folders
        where parent_id = v_past_papers and name = v_exam_system.name
      );
  end loop;
end $$;
