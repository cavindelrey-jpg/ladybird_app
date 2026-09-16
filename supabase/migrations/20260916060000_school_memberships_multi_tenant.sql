-- 20260916060000_school_memberships_multi_tenant.sql
-- Establishes a strict multi-tenant boundary model by extracting school-specific
-- enrollments out of the global public.users table into a dedicated school_memberships table.
-- This ensures a student's Academia identity is preserved while isolating official school data.

CREATE TABLE IF NOT EXISTS public.school_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    school_id UUID NOT NULL, -- references institutions, but avoiding strict FK in case of loose coupling
    role TEXT NOT NULL DEFAULT 'guest',
    class_level TEXT,
    department_id UUID,
    teaching_assignments JSONB DEFAULT '[]'::jsonb,
    class_master_of_class TEXT,
    school_voucher_ref TEXT,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, school_id)
);

ALTER TABLE public.school_memberships ENABLE ROW LEVEL SECURITY;

-- Users can read their own memberships. Admins can read memberships in their school.
CREATE POLICY "Users can view their own memberships"
    ON public.school_memberships FOR SELECT
    USING (user_id = auth.uid() OR school_id IN (
        SELECT school_id FROM public.school_memberships 
        WHERE user_id = auth.uid() AND role IN ('school_admin', 'super_admin', 'department_admin')
    ));

-- Migrate existing data
INSERT INTO public.school_memberships (
    user_id, school_id, role, class_level, department_id, 
    teaching_assignments, class_master_of_class, school_voucher_ref
)
SELECT 
    id, institution_id, COALESCE(school_role, 'guest'), class_level, department_id,
    COALESCE(teaching_assignments, '[]'::jsonb), class_master_of_class, school_voucher_ref
FROM public.users
WHERE institution_id IS NOT NULL
ON CONFLICT (user_id, school_id) DO NOTHING;

-- Update RLS on school_marks to use the new multi-tenant layer
DROP POLICY IF EXISTS "school marks select" ON public.school_marks;
CREATE POLICY "school marks select" ON public.school_marks
  FOR SELECT
  USING (
    student_id = auth.uid()
    OR school_id IN (
      SELECT school_id FROM public.school_memberships
      WHERE user_id = auth.uid() AND role IN ('lecturer', 'department_admin', 'school_admin', 'super_admin', 'teacher', 'admin')
    )
  );

DROP POLICY IF EXISTS "school marks insert" ON public.school_marks;
CREATE POLICY "school marks insert" ON public.school_marks
  FOR INSERT
  WITH CHECK (
    school_id IN (
      SELECT school_id FROM public.school_memberships
      WHERE user_id = auth.uid() AND role IN ('lecturer', 'department_admin', 'school_admin', 'super_admin', 'teacher', 'admin')
    )
  );

DROP POLICY IF EXISTS "school marks update" ON public.school_marks;
CREATE POLICY "school marks update" ON public.school_marks
  FOR UPDATE
  USING (
    school_id IN (
      SELECT school_id FROM public.school_memberships
      WHERE user_id = auth.uid() AND role IN ('lecturer', 'department_admin', 'school_admin', 'super_admin', 'teacher', 'admin')
    )
  )
  WITH CHECK (
    school_id IN (
      SELECT school_id FROM public.school_memberships
      WHERE user_id = auth.uid() AND role IN ('lecturer', 'department_admin', 'school_admin', 'super_admin', 'teacher', 'admin')
    )
  );

DROP POLICY IF EXISTS "school marks delete" ON public.school_marks;
CREATE POLICY "school marks delete" ON public.school_marks
  FOR DELETE
  USING (
    school_id IN (
      SELECT school_id FROM public.school_memberships
      WHERE user_id = auth.uid() AND role IN ('lecturer', 'department_admin', 'school_admin', 'super_admin', 'teacher', 'admin')
    )
  );

-- Update timetable policies
DROP POLICY IF EXISTS "school timetable select" ON public.school_timetable_slots;
CREATE POLICY "school timetable select" ON public.school_timetable_slots
  FOR SELECT
  USING (school_id IN (SELECT school_id FROM public.school_memberships WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "school timetable insert" ON public.school_timetable_slots;
CREATE POLICY "school timetable insert" ON public.school_timetable_slots
  FOR INSERT
  WITH CHECK (
    school_id IN (
      SELECT school_id FROM public.school_memberships
      WHERE user_id = auth.uid() AND role IN ('school_admin', 'super_admin', 'admin')
    )
  );

DROP POLICY IF EXISTS "school timetable update" ON public.school_timetable_slots;
CREATE POLICY "school timetable update" ON public.school_timetable_slots
  FOR UPDATE
  USING (
    school_id IN (
      SELECT school_id FROM public.school_memberships
      WHERE user_id = auth.uid() AND role IN ('school_admin', 'super_admin', 'admin')
    )
  )
  WITH CHECK (
    school_id IN (
      SELECT school_id FROM public.school_memberships
      WHERE user_id = auth.uid() AND role IN ('school_admin', 'super_admin', 'admin')
    )
  );

DROP POLICY IF EXISTS "school timetable delete" ON public.school_timetable_slots;
CREATE POLICY "school timetable delete" ON public.school_timetable_slots
  FOR DELETE
  USING (
    school_id IN (
      SELECT school_id FROM public.school_memberships
      WHERE user_id = auth.uid() AND role IN ('school_admin', 'super_admin', 'admin')
    )
  );

-- Note: In a subsequent migration, the old columns (institution_id, school_role, class_level)
-- will be dropped from public.users once all clients are on the new AppUser model.
