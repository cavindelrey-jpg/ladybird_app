-- 20260904000006_parent_student_linking.sql
-- Spec item 5: "A parent linked to that student must be able to open
-- the app and see the appropriate student information... Do not expose
-- information belonging to unrelated students." No durable parent<->
-- student link exists anywhere today -- SchoolVoucher already models
-- half of this (a parent-role voucher carries linked_student_voucher_id,
-- see lib/models/school_voucher.dart's "School -> Student -> Parent"
-- redesign comment) but nothing ever turns that into a lasting
-- parent_id/student_id relationship once both vouchers get redeemed
-- (possibly by different people, possibly in either order, possibly
-- days apart). This migration is purely additive -- a new table + a
-- new AFTER UPDATE trigger on the existing school_vouchers table -- on
-- purpose: redeem_school_voucher() itself isn't defined in this repo
-- (base schema lives in the sibling greenhills_app repo, shared
-- Supabase project) so its current body can't be safely read or
-- CREATE OR REPLACE'd without risking silently dropping behavior it
-- already has. A trigger on the same table's UPDATE achieves the same
-- outcome without touching that function at all.
--
-- Table named academia_parent_student_links, not the more obvious
-- parent_student_links: a live push against the real project hit
-- "column student_id does not exist" on the CREATE INDEX right after
-- CREATE TABLE IF NOT EXISTS -- the only way that happens is a table
-- already named public.parent_student_links exists with some other,
-- incompatible shape (almost certainly from the sibling greenhills_app
-- repo, same shared Supabase project, whose schema isn't visible from
-- here -- no Docker for `supabase db dump`, no service_role key for a
-- PostgREST OpenAPI introspection, no stored DB password for a direct
-- psql session). Renaming avoids touching or guessing at an unknown
-- table something else may depend on.

create table if not exists public.academia_parent_student_links (
  parent_id uuid not null references auth.users(id) on delete cascade,
  student_id uuid not null references auth.users(id) on delete cascade,
  school_id uuid references public.institutions(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (parent_id, student_id)
);

create index if not exists academia_parent_student_links_student_idx on public.academia_parent_student_links (student_id);

alter table public.academia_parent_student_links enable row level security;

drop policy if exists "parent student links select own" on public.academia_parent_student_links;
create policy "parent student links select own" on public.academia_parent_student_links
  for select
  using (parent_id = auth.uid() or student_id = auth.uid());

-- Admins of the school can view/correct links for their own school —
-- e.g. a parent who claims the wrong code, or a re-issued voucher.
drop policy if exists "parent student links admin manage" on public.academia_parent_student_links;
create policy "parent student links admin manage" on public.academia_parent_student_links
  for all
  using (
    school_id in (
      select institution_id from public.users
      where id = auth.uid() and role in ('school_admin', 'super_admin')
    )
  )
  with check (
    school_id in (
      select institution_id from public.users
      where id = auth.uid() and role in ('school_admin', 'super_admin')
    )
  );

-- Fires on every school_vouchers UPDATE (redemption sets status +
-- redeemed_by_user_id); handles both possible redemption orders —
-- parent-redeems-first (looks up whether the linked student voucher is
-- already redeemed) and student-redeems-first (looks up any
-- already-redeemed parent voucher pointing at this one).
create or replace function public.link_parent_on_voucher_redeem()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_parent_user_id uuid;
  v_student_user_id uuid;
begin
  if new.status <> 'redeemed' or new.redeemed_by_user_id is null then
    return new;
  end if;
  if old.status = 'redeemed' and old.redeemed_by_user_id = new.redeemed_by_user_id then
    return new;
  end if;

  if new.role = 'parent' and new.linked_student_voucher_id is not null then
    select redeemed_by_user_id into v_student_user_id
      from public.school_vouchers
      where id = new.linked_student_voucher_id and status = 'redeemed';
    if v_student_user_id is not null then
      insert into public.academia_parent_student_links (parent_id, student_id, school_id)
      values (new.redeemed_by_user_id, v_student_user_id, new.school_id)
      on conflict (parent_id, student_id) do nothing;
    end if;
  elsif new.role = 'student' then
    for v_parent_user_id in
      select redeemed_by_user_id from public.school_vouchers
      where linked_student_voucher_id = new.id and role = 'parent' and status = 'redeemed'
        and redeemed_by_user_id is not null
    loop
      insert into public.academia_parent_student_links (parent_id, student_id, school_id)
      values (v_parent_user_id, new.redeemed_by_user_id, new.school_id)
      on conflict (parent_id, student_id) do nothing;
    end loop;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_link_parent_on_voucher_redeem on public.school_vouchers;
create trigger trg_link_parent_on_voucher_redeem
  after update on public.school_vouchers
  for each row execute function public.link_parent_on_voucher_redeem();

-- Narrow, purpose-built read for the parent dashboard's student picker —
-- deliberately NOT a broadened public.users SELECT policy: that policy
-- isn't defined in this repo either, so it can't be safely inspected or
-- extended blind, and a SECURITY DEFINER RPC returning only the handful
-- of fields the parent UI actually needs (not email, vouchers, XP, etc.)
-- is the more conservative, least-privilege choice anyway.
create or replace function public.get_linked_students(p_parent_id uuid)
returns table (student_id uuid, student_name text, class_level text, institution_id uuid, photo_url text)
language sql
security definer
set search_path = public
stable
as $$
  select u.id, u.name, u.class_level, u.institution_id, u.photo_url
  from public.academia_parent_student_links pl
  join public.users u on u.id = pl.student_id
  where pl.parent_id = p_parent_id;
$$;

-- ── Extend the three tables item 5 actually asks a parent to see
--    (marks, homework, timetable) with a "viewing your own linked
--    child's row" bypass, on top of every existing clause unchanged. ──

drop policy if exists "school marks select" on public.school_marks;
create policy "school marks select" on public.school_marks
  for select
  using (
    student_id = auth.uid()
    or school_id in (
      select institution_id from public.users
      where id = auth.uid() and role in ('lecturer', 'department_admin', 'school_admin', 'super_admin')
    )
    or exists (
      select 1 from public.academia_parent_student_links pl
      where pl.parent_id = auth.uid() and pl.student_id = school_marks.student_id
    )
  );

drop policy if exists "homework select" on public.homework;
create policy "homework select" on public.homework
  for select
  using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.institution_id = homework.school_id
        and (u.class_level = homework.class_level
             or u.role in ('lecturer', 'department_admin', 'school_admin', 'super_admin'))
    )
    or exists (
      select 1 from public.academia_parent_student_links pl
      join public.users su on su.id = pl.student_id
      where pl.parent_id = auth.uid()
        and su.institution_id = homework.school_id
        and su.class_level = homework.class_level
    )
  );

drop policy if exists "school timetable select" on public.school_timetable_slots;
create policy "school timetable select" on public.school_timetable_slots
  for select
  using (
    school_id in (select institution_id from public.users where id = auth.uid())
    or exists (
      select 1 from public.academia_parent_student_links pl
      join public.users su on su.id = pl.student_id
      where pl.parent_id = auth.uid()
        and su.institution_id = school_timetable_slots.school_id
        and su.class_level = school_timetable_slots.class_level
    )
  );
