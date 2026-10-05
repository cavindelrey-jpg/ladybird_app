-- ============================================================================
-- Academia Cameroon — Row Level Security policies
-- Phase 2 of the Firebase -> Supabase runbook. Builds on supabase/schema.sql
-- (Phase 1). Every policy below is traced back to the matching
-- firestore.rules block documented in MIGRATION_INVENTORY.md section 5,
-- or to the three bullet points given for this phase where the rules
-- file doesn't cover a case explicitly.
--
-- Do not apply this to any database yet.
-- ============================================================================

-- ============================================================================
-- Helper functions
-- Mirrors firestore.rules:20-58 (myRole/roleLevel/hasMinRole). SECURITY
-- DEFINER + a fixed search_path so these bypass RLS on their internal
-- lookup against public.users — without that, a policy on public.users
-- calling current_role() would recurse into itself via RLS and either
-- infinite-loop or (depending on the read) return nothing.
-- ============================================================================

create or replace function public.current_role()
returns user_role
language sql stable security definer set search_path = public as $$
  select role from public.users where id = auth.uid();
$$;

create or replace function public.current_institution_id()
returns uuid
language sql stable security definer set search_path = public as $$
  select institution_id from public.users where id = auth.uid();
$$;

-- Ordinal comparison, same table as firestore.rules:41-46's roleLevel().
create or replace function public.role_level(r user_role)
returns int
language sql immutable as $$
  select case r
    when 'super_admin'       then 5
    when 'school_admin'      then 4
    when 'department_admin'  then 3
    when 'lecturer'          then 2
    when 'student'           then 1
    else 0 -- 'guest'
  end;
$$;

-- Mirrors hasMinRole(role) in firestore.rules:52. Returns false (not
-- null) for a signed-out caller, so it's always safe to use directly in
-- a USING/WITH CHECK clause.
create or replace function public.has_min_role(min_role user_role)
returns boolean
language sql stable as $$
  select coalesce(public.role_level(public.current_role()) >= public.role_level(min_role), false);
$$;

-- ============================================================================
-- institutions
-- Mirrors firestore.rules:172-175 — public read, superAdmin-only write.
-- ============================================================================
alter table public.institutions enable row level security;

create policy "institutions_select_all"
  on public.institutions for select
  using (true);

create policy "institutions_write_super_admin"
  on public.institutions for all
  using (public.has_min_role('super_admin'))
  with check (public.has_min_role('super_admin'));

-- ============================================================================
-- users
-- MIGRATION_INVENTORY.md section 5: self-read/write plus role-gated admin
-- paths, admin threshold = canManageUsers() = departmentAdmin+
-- (firestore.rules:53). No insert policy: rows are created by the
-- handle_new_user trigger (schema.sql), which runs as security definer.
-- ============================================================================
alter table public.users enable row level security;

create policy "users_select_self_or_admin"
  on public.users for select
  using (id = auth.uid() or public.has_min_role('department_admin'));

create policy "users_update_self"
  on public.users for update
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "users_update_admin"
  on public.users for update
  using (public.has_min_role('department_admin'))
  with check (public.has_min_role('department_admin'));

-- Permissive policies for the same command (UPDATE here) combine with OR,
-- so a self-editing student and a department admin editing someone else
-- are both covered without either policy needing to special-case the
-- other's condition.

-- ============================================================================
-- student_accounts
-- Phase 2 spec, bullet 1: "Students can only read/write their own
-- student_accounts row." Implemented as user_id = auth.uid(), widened to
-- institution-scoped school_admin+ and unscoped super_admin so seat
-- provisioning/admin support actually works — a literal "only the
-- student" policy would make createSeat/assignSeat (accounts_repository.
-- dart) impossible to reproduce.
--
-- Known gap, not solved here: a freshly-created seat has user_id = NULL
-- until the student's first login links it — RLS can't help a caller who
-- doesn't have a Supabase Auth session yet tied to that row. The
-- account-ID + temp-password claim step itself needs a SECURITY DEFINER
-- RPC (looks the seat up by account_id, verifies temp_password, then
-- sets user_id post-auth-creation) — that's Phase 3's "Auth migration
-- plan" territory, not something to improvise here.
-- ============================================================================
alter table public.student_accounts enable row level security;

create policy "student_accounts_select_own_or_admin"
  on public.student_accounts for select
  using (
    user_id = auth.uid()
    or public.has_min_role('super_admin')
    or (public.has_min_role('school_admin')
        and institution_id = public.current_institution_id())
  );

create policy "student_accounts_update_own_or_admin"
  on public.student_accounts for update
  using (
    user_id = auth.uid()
    or public.has_min_role('super_admin')
    or (public.has_min_role('school_admin')
        and institution_id = public.current_institution_id())
  )
  with check (
    user_id = auth.uid()
    or public.has_min_role('super_admin')
    or (public.has_min_role('school_admin')
        and institution_id = public.current_institution_id())
  );

-- Seat provisioning (create) and hard delete stay admin-only — a student
-- never creates or deletes their own seat row, matching
-- firestore.rules:159-166 (create/delete gated to canManageSchool()).
create policy "student_accounts_insert_admin"
  on public.student_accounts for insert
  with check (
    public.has_min_role('super_admin')
    or (public.has_min_role('school_admin')
        and institution_id = public.current_institution_id())
  );

create policy "student_accounts_delete_admin"
  on public.student_accounts for delete
  using (
    public.has_min_role('super_admin')
    or (public.has_min_role('school_admin')
        and institution_id = public.current_institution_id())
  );

-- ============================================================================
-- serials
-- Phase 2 spec, bullet 2: "Only schoolAdmin/superAdmin can write to the
-- serials table." Read stays public (firestore.rules and the undeployed
-- firestore (1).rules both agree: "allow read: if true" — the claim-seat
-- preview screen shows institution branding before the student has an
-- account, let alone a session).
--
-- This literally blocks a student's own claim/release UPDATE under RLS —
-- intentional. schema.sql's own TODO on this table already flagged that
-- the claim compare-and-swap belongs in a SECURITY DEFINER function
-- rather than a client-side UPDATE; claim_serial()/release_serial() below
-- implement that, so self-service claiming still works despite the table
-- itself being writable only by school_admin+.
-- ============================================================================
alter table public.serials enable row level security;

create policy "serials_select_all"
  on public.serials for select
  using (true);

create policy "serials_write_school_admin"
  on public.serials for all
  using (
    public.has_min_role('super_admin')
    or (public.has_min_role('school_admin')
        and institution_id = public.current_institution_id())
  )
  with check (
    public.has_min_role('super_admin')
    or (public.has_min_role('school_admin')
        and institution_id = public.current_institution_id())
  );

-- Runs as the function owner, so it bypasses the school_admin-only policy
-- above by design — the compare-and-swap logic it enforces IS the access
-- control for this one narrow case, same invariant as the transaction in
-- serial_repository.dart:95-119.
create or replace function public.claim_serial(p_code text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_status serial_status;
begin
  if auth.uid() is null then
    raise exception 'Must be signed in to claim a serial.';
  end if;

  select status into v_status from public.serials where code = p_code for update;

  if v_status is null then
    raise exception 'Serial number no longer exists.';
  end if;
  if v_status <> 'unclaimed' then
    raise exception 'This serial number has already been claimed.';
  end if;

  update public.serials
    set status = 'claimed', claimed_by = auth.uid(), claimed_at = now()
    where code = p_code;
end;
$$;

-- Rollback path, mirrors serial_repository.dart:120-133 (release()) —
-- only the same uid that just claimed it can undo the claim, and only
-- while it's still 'claimed'.
create or replace function public.release_serial(p_code text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.serials
    set status = 'unclaimed', claimed_by = null, claimed_at = null
    where code = p_code and status = 'claimed' and claimed_by = auth.uid();
end;
$$;

-- ============================================================================
-- library_items / courses / magazine_articles
-- Phase 2 spec, bullet 3: "readable by any authenticated user, writable
-- only by lecturer/departmentAdmin/schoolAdmin/superAdmin." Matches
-- canUploadContent() = lecturer+ in firestore.rules:59.
--
-- Note: this is a stricter read policy than what schema.sql's own TODOs
-- guessed at (public/unauthenticated read for marketplace content) — the
-- Phase 2 spec says "authenticated user" explicitly, so that's what's
-- implemented here. Revisit if Library/Courses/Magazine are meant to be
-- browsable while signed out (confirm against actual screen behavior,
-- e.g. whether course_browse_page.dart is reachable pre-auth).
-- ============================================================================
alter table public.library_items enable row level security;

create policy "library_items_select_authenticated"
  on public.library_items for select
  using (auth.uid() is not null);

create policy "library_items_write_lecturer"
  on public.library_items for all
  using (public.has_min_role('lecturer'))
  with check (public.has_min_role('lecturer'));

alter table public.courses enable row level security;

create policy "courses_select_authenticated"
  on public.courses for select
  using (auth.uid() is not null);

create policy "courses_write_lecturer"
  on public.courses for all
  using (public.has_min_role('lecturer'))
  with check (public.has_min_role('lecturer'));

alter table public.magazine_articles enable row level security;

create policy "magazine_articles_select_authenticated"
  on public.magazine_articles for select
  using (auth.uid() is not null);

create policy "magazine_articles_write_lecturer"
  on public.magazine_articles for all
  using (public.has_min_role('lecturer'))
  with check (public.has_min_role('lecturer'));
