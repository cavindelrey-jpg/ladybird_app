-- supabase/migrations/20261007000000_fix_club_tenant_backfill.sql
--
-- Repairs the over-aggressive backfill introduced by
-- 20261004210000_enforce_club_tenant_isolation.sql.
--
-- That migration resolved a club's institution_id from (1) the moderator's
-- institution_id, then (2) a keyword match on the club name/description, and
-- finally (3) a blanket fallback that dumped EVERY remaining club into
-- institution_id = 'academia'. Any Green Hills club whose creating account had
-- no institution_id at the time AND whose name did not literally contain
-- "green hill"/"greenhill" (e.g. "Debate Club", "Chess Society") fell through
-- to step (3) and was tagged 'academia'. In a school-branded build
-- ClubScope.canAccessClub only shows clubs whose tenant matches the app's own
-- school, so those clubs vanished from the Green Hills app — the "Groups are no
-- longer available" regression.
--
-- This migration (a) canonicalizes tenant slugs so exact-match server filters
-- line up with ClubScope.normalizeSchoolId, and (b) reclaims clubs that were
-- swept into 'academia' even though their moderator belongs to a real school.
-- It is idempotent and safe to re-run.

-- ── Helper: mirror ClubScope.normalizeSchoolId (lib/core/club_scope.dart) ──
-- Keep these cases in sync with the Dart implementation.
CREATE OR REPLACE FUNCTION public.canonical_school_id(p text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p IS NULL OR trim(p) = '' THEN NULL
    WHEN lower(trim(p)) IN ('green_hill','green_hills','greenhill','greenhills') THEN 'green_hill'
    WHEN lower(trim(p)) IN ('ladybird','ladybird_app','lady_bird')               THEN 'ladybird'
    WHEN lower(trim(p)) IN ('st_stephen','ststephen','st_stephens')              THEN 'st_stephen'
    WHEN lower(trim(p)) IN ('academia','general','academia_general')             THEN 'academia'
    ELSE lower(trim(p))
  END;
$$;

-- Step 1: Canonicalize existing tenant slugs on both columns. A row stored as
-- 'green_hills' would never match the app's `.eq('institution_id','green_hill')`
-- realtime filter, so normalize it at the source.
UPDATE public.clubs
SET institution_id = public.canonical_school_id(institution_id)
WHERE institution_id IS NOT NULL
  AND institution_id IS DISTINCT FROM public.canonical_school_id(institution_id);

UPDATE public.clubs
SET school_id = public.canonical_school_id(school_id)
WHERE school_id IS NOT NULL
  AND school_id IS DISTINCT FROM public.canonical_school_id(school_id);

-- Step 2: Reclaim clubs the previous migration dumped into 'academia' even
-- though their moderator belongs to a real school. Because the
-- trg_enforce_club_tenant trigger already stamps new clubs with the creating
-- user's institution_id, a club sitting at 'academia' whose moderator has a
-- non-academia school could only be a legacy club that lost its tag — exactly
-- the rows the aggressive step-3 fallback mislabeled. Genuinely general clubs
-- are created by users with no school and are left untouched.
UPDATE public.clubs c
SET institution_id = public.canonical_school_id(u.institution_id)
FROM public.users u
WHERE c.moderator_id = u.id
  AND c.institution_id = 'academia'
  AND u.institution_id IS NOT NULL
  AND u.institution_id <> ''
  AND public.canonical_school_id(u.institution_id) <> 'academia';

-- Step 3: Keep school_id and institution_id consistent after the reclaim so the
-- app's dual-column reads (`school_id ?? institution_id`) and the single-column
-- realtime stream filter agree.
UPDATE public.clubs
SET school_id = institution_id
WHERE institution_id IS NOT NULL AND institution_id <> ''
  AND (school_id IS NULL OR school_id = '' OR school_id IS DISTINCT FROM institution_id);

UPDATE public.clubs
SET institution_id = school_id
WHERE school_id IS NOT NULL AND school_id <> ''
  AND (institution_id IS NULL OR institution_id = '');
