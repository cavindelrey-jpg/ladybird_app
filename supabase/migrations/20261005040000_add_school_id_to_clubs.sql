-- supabase/migrations/20261005040000_add_school_id_to_clubs.sql
--
-- Explicitly add school_id column to public.clubs to guarantee uniform tenant
-- identifier semantics alongside institution_id.
-- Keeps school_id and institution_id synchronized for seamless compatibility.

ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS school_id text;

-- Backfill school_id from existing institution_id
UPDATE public.clubs
SET school_id = institution_id
WHERE school_id IS NULL AND institution_id IS NOT NULL;

-- Automatically keep school_id and institution_id in sync on future writes
CREATE OR REPLACE FUNCTION public.trg_sync_club_school_id()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.school_id IS NOT NULL AND (NEW.institution_id IS NULL OR NEW.institution_id = '') THEN
    NEW.institution_id := NEW.school_id;
  ELSIF NEW.institution_id IS NOT NULL AND (NEW.school_id IS NULL OR NEW.school_id = '') THEN
    NEW.school_id := NEW.institution_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_club_school_id ON public.clubs;
CREATE TRIGGER trg_sync_club_school_id
  BEFORE INSERT OR UPDATE ON public.clubs
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_sync_club_school_id();

CREATE INDEX IF NOT EXISTS idx_clubs_school_id ON public.clubs (school_id);
