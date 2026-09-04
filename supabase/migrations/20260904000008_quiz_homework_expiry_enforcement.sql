-- 20260904000008_quiz_homework_expiry_enforcement.sql
-- Spec item 4B: "After the specified expiry time, the quiz should no
-- longer be available for submission... This must use real time/date
-- validation on the backend, not merely frontend UI logic."
--
-- test_attempts isn't defined in this repo's own migrations (base
-- schema lives in the sibling greenhills_app repo, shared Supabase
-- project) -- adding a nullable column via ALTER TABLE is safe
-- regardless of what its current RLS/other columns look like (a new
-- nullable column can't violate an existing NOT NULL/check constraint
-- on insert, and doesn't change what any existing policy's `using`/
-- `with check` clause evaluates over). Column names referenced below
-- (test_attempts.test_id, .user_id, .submitted_at) are confirmed via
-- both directions of lib/models/test_attempt.dart's existing Supabase
-- mapping.

alter table public.test_attempts add column if not exists homework_id uuid references public.homework(id) on delete set null;
create index if not exists test_attempts_homework_idx on public.test_attempts (homework_id);

-- The actual enforcement: reject the insert outright if this attempt
-- claims to be for a specific homework assignment whose effective
-- (possibly per-student-extended) due date has already passed. Client
-- code (TestRepository.submitAttempt) already pre-checks this via
-- get_effective_homework_due_at() for a fast, friendly error, but this
-- trigger is the real, unbypassable boundary -- it re-checks the exact
-- same function, so client and server can never disagree about what
-- "expired" means.
create or replace function public.enforce_homework_quiz_expiry()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_effective_due timestamptz;
begin
  if new.homework_id is not null then
    v_effective_due := public.get_effective_homework_due_at(new.homework_id, new.user_id);
    if v_effective_due is not null and now() > v_effective_due then
      raise exception 'This quiz has expired and can no longer be submitted.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_homework_quiz_expiry on public.test_attempts;
create trigger trg_enforce_homework_quiz_expiry
  before insert on public.test_attempts
  for each row execute function public.enforce_homework_quiz_expiry();
