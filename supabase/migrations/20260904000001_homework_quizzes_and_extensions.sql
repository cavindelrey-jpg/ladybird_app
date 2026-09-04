-- 20260904000001_homework_quizzes_and_extensions.sql
-- Adds Quiz Support to Homework and Student-Specific Deadline Extensions

ALTER TABLE public.homework ADD COLUMN test_id UUID REFERENCES public.tests(id);

CREATE TABLE IF NOT EXISTS public.homework_extensions (
  homework_id UUID NOT NULL REFERENCES public.homework(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  new_due_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id),
  PRIMARY KEY (homework_id, student_id)
);

ALTER TABLE public.homework_extensions ENABLE ROW LEVEL SECURITY;

-- Teachers can manage extensions for homework they own
CREATE POLICY "homework extensions all" ON public.homework_extensions
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.homework h
      WHERE h.id = homework_id AND (h.teacher_id = auth.uid() OR EXISTS (
        SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role IN ('school_admin', 'super_admin')
      ))
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.homework h
      WHERE h.id = homework_id AND (h.teacher_id = auth.uid() OR EXISTS (
        SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role IN ('school_admin', 'super_admin')
      ))
    )
  );

-- Students can read their own extensions
CREATE POLICY "homework extensions select student" ON public.homework_extensions
  FOR SELECT
  USING (student_id = auth.uid());

-- Function to get the effective due date for a student for a specific homework
CREATE OR REPLACE FUNCTION public.get_effective_homework_due_at(p_homework_id UUID, p_student_id UUID)
RETURNS TIMESTAMPTZ AS $$
DECLARE
  v_ext TIMESTAMPTZ;
  v_base TIMESTAMPTZ;
BEGIN
  SELECT new_due_at INTO v_ext FROM public.homework_extensions WHERE homework_id = p_homework_id AND student_id = p_student_id;
  IF v_ext IS NOT NULL THEN
    RETURN v_ext;
  END IF;
  
  SELECT due_at INTO v_base FROM public.homework WHERE id = p_homework_id;
  RETURN v_base;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

