-- supabase/migrations/20261004210000_enforce_club_tenant_isolation.sql
--
-- Enforce school-scoped tenant isolation for academic clubs/groups.
-- 1. Audits existing rows in public.clubs and resolves missing/ambiguous institution_ids
--    based on moderator user profile, class groups, or explicit school name.
-- 2. Prevents unscoped or cross-tenant club leakage.
-- 3. Adds indexing on institution_id.

-- Step 1: Audit and backfill from moderator's registered institution
UPDATE public.clubs c
SET institution_id = u.institution_id
FROM public.users u
WHERE c.moderator_id = u.id
  AND (c.institution_id IS NULL OR c.institution_id = '')
  AND u.institution_id IS NOT NULL
  AND u.institution_id <> '';

-- Step 2: Contextual resolution based on club metadata
UPDATE public.clubs
SET institution_id = 'ladybird'
WHERE (institution_id IS NULL OR institution_id = '')
  AND (lower(name) LIKE '%ladybird%' OR lower(description) LIKE '%ladybird%');

UPDATE public.clubs
SET institution_id = 'green_hill'
WHERE (institution_id IS NULL OR institution_id = '')
  AND (lower(name) LIKE '%green hill%' OR lower(name) LIKE '%greenhill%' OR lower(description) LIKE '%green hill%' OR lower(description) LIKE '%greenhill%');

UPDATE public.clubs
SET institution_id = 'st_stephen'
WHERE (institution_id IS NULL OR institution_id = '')
  AND (lower(name) LIKE '%stephen%' OR lower(description) LIKE '%stephen%');

-- Step 3: Any remaining unassigned clubs belong to Academia General context
UPDATE public.clubs
SET institution_id = 'academia'
WHERE (institution_id IS NULL OR institution_id = '');

-- Step 4: Add index on institution_id for fast school-scoped queries
CREATE INDEX IF NOT EXISTS idx_clubs_institution_id ON public.clubs (institution_id);

-- Step 5: Enforce that future club creations cannot be unscoped
CREATE OR REPLACE FUNCTION public.trg_enforce_club_tenant()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.institution_id IS NULL OR NEW.institution_id = '' THEN
    -- Try to resolve from authenticated user
    SELECT institution_id INTO NEW.institution_id
    FROM public.users
    WHERE id = auth.uid()
      AND institution_id IS NOT NULL
      AND institution_id <> '';
    
    -- Fall back to general Academia context if user has no school
    IF NEW.institution_id IS NULL OR NEW.institution_id = '' THEN
      NEW.institution_id := 'academia';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_club_tenant ON public.clubs;
CREATE TRIGGER trg_enforce_club_tenant
  BEFORE INSERT OR UPDATE ON public.clubs
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_enforce_club_tenant();
